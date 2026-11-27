import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, symlinkSync, unlinkSync, writeFileSync, chmodSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { checkPath, digestOf, githubClient, parseRaw, publishSnapshot, takeSnapshot } from '../lib/publish.mjs';

const git = (cwd, ...a) => execFileSync('git', a, { cwd, encoding: 'utf8', env: { ...process.env, GIT_AUTHOR_NAME: 't', GIT_AUTHOR_EMAIL: 't@t', GIT_COMMITTER_NAME: 't', GIT_COMMITTER_EMAIL: 't@t' } });

/** An upstream repo and a clone of it, as the familiar leaves it in the VM. */
function fixture() {
  const root = mkdtempSync(join(tmpdir(), 'rf-pub-'));
  const up = join(root, 'up');
  execFileSync('mkdir', ['-p', up]);
  git(up, 'init', '-q', '-b', 'main');
  writeFileSync(join(up, 'keep.txt'), 'keep\n');
  writeFileSync(join(up, 'edit.txt'), 'old\n');
  writeFileSync(join(up, 'gone.txt'), 'bye\n');
  writeFileSync(join(up, '.gitignore'), 'node_modules/\n');
  git(up, 'add', '-A');
  git(up, 'commit', '-qm', 'base');
  const repo = join(root, 'repo');
  git(root, 'clone', '-q', up, repo);
  return { root, up, repo, base: git(repo, 'rev-parse', 'HEAD').trim() };
}

/** The VM interface, run on this machine. */
const localVm = {
  run: async (script) => {
    const r = spawnSync('bash', ['-c', script.replace("git config --global --add safe.directory '*' >/dev/null 2>&1 || true", ':').replaceAll('/tmp/rf', `${tmpdir()}/rf-${process.pid}`)], { encoding: 'utf8' });
    return { code: r.status, out: r.status === 0 ? r.stdout : `${r.stdout}\n${r.stderr}` };
  },
  readFile: async (p) => readFileSync(p.replace('/tmp/rf', `${tmpdir()}/rf-${process.pid}`)),
};

test('takeSnapshot takes added, modified, deleted and committed files, not ignored ones', async () => {
  const { root, repo, base } = fixture();
  try {
    writeFileSync(join(repo, 'edit.txt'), 'new\n');
    unlinkSync(join(repo, 'gone.txt'));
    writeFileSync(join(repo, 'added.bin'), Buffer.from([0, 1, 2, 255]));
    execFileSync('mkdir', ['-p', join(repo, 'node_modules')]);
    writeFileSync(join(repo, 'node_modules', 'x.js'), 'x');
    writeFileSync(join(repo, 'committed.txt'), 'c\n');
    git(repo, 'add', 'committed.txt');
    git(repo, 'commit', '-qm', 'agent commit');
    const s = await takeSnapshot(localVm, repo);
    assert.equal(s.base, base);
    const byPath = Object.fromEntries(s.files.map((f) => [f.path, f]));
    assert.deepEqual(Object.keys(byPath).sort(), ['added.bin', 'committed.txt', 'edit.txt', 'gone.txt']);
    assert.equal(byPath['edit.txt'].status, 'M');
    assert.equal(byPath['edit.txt'].content.toString(), 'new\n');
    assert.equal(byPath['gone.txt'].status, 'D');
    assert.equal(byPath['gone.txt'].content, undefined);
    assert.deepEqual([...byPath['added.bin'].content], [0, 1, 2, 255]);
    assert.match(s.patch, /diff --git a\/edit.txt b\/edit.txt/);
    assert.equal(s.digest, digestOf(base, s.files));
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test('takeSnapshot refuses symlinks and notes a lost executable bit', async () => {
  const { root, repo } = fixture();
  try {
    writeFileSync(join(repo, 'run.sh'), '#!/bin/sh\n');
    chmodSync(join(repo, 'run.sh'), 0o755);
    const s = await takeSnapshot(localVm, repo);
    assert.match(s.notes.join('\n'), /run.sh: the executable bit is lost/);
    symlinkSync('keep.txt', join(repo, 'link'));
    await assert.rejects(takeSnapshot(localVm, repo), /symlinks and submodules/);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test('takeSnapshot with no changes has no files', async () => {
  const { root, repo } = fixture();
  try {
    const s = await takeSnapshot(localVm, repo);
    assert.equal(s.files.length, 0);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test('parseRaw and checkPath', () => {
  const z = '0'.repeat(40), a = 'a'.repeat(40);
  assert.deepEqual(parseRaw(`:000000 100644 ${z} ${a} A\0new file.txt\0`), [{ oldMode: '000000', newMode: '100644', oldSha: z, newSha: a, status: 'A', path: 'new file.txt' }]);
  assert.throws(() => parseRaw(':bogus\0x\0'), /unexpected raw diff record/);
  for (const bad of ['../x', '/etc/passwd', 'a/.git/config', '']) assert.throws(() => checkPath(bad), /unsafe path/);
  checkPath('src/ok.ts');
});

function fakeGithub({ exists = false } = {}) {
  const calls = [];
  return {
    calls,
    repo: async (r) => { calls.push(['repo', r]); return { default_branch: 'main' }; },
    commit: async (r, sha) => { calls.push(['commit', sha]); return {}; },
    branchExists: async (r, b) => { calls.push(['branchExists', b]); return exists; },
    createBranch: async (r, b, sha) => { calls.push(['createBranch', b, sha]); return {}; },
    commitOnBranch: async (input) => { calls.push(['commitOnBranch', input]); return { oid: 'c'.repeat(40), signature: { isValid: true } }; },
    openPr: async (r, pr) => { calls.push(['openPr', pr]); return { html_url: 'https://github.com/o/r/pull/7', number: 7 }; },
  };
}

const snap = { base: 'b'.repeat(40), files: [{ path: 'a.txt', status: 'M', content: Buffer.from('hi') }, { path: 'old.txt', status: 'D' }], patch: '', notes: [] };

test('publishSnapshot branches at the base, commits the snapshot, opens the PR', async () => {
  const gh = fakeGithub();
  const out = await publishSnapshot({ github: gh, repo: 'o/r', branch: 'vercel-sandbox/x', snapshot: snap, title: 'fix: x', body: 'why' });
  assert.deepEqual(out, { branch: 'vercel-sandbox/x', commit: 'c'.repeat(40), verified: true, pr: 'https://github.com/o/r/pull/7', number: 7 });
  const input = gh.calls.find((c) => c[0] === 'commitOnBranch')[1];
  assert.equal(input.expectedHeadOid, snap.base);
  assert.deepEqual(input.fileChanges, { additions: [{ path: 'a.txt', contents: Buffer.from('hi').toString('base64') }], deletions: [{ path: 'old.txt' }] });
  assert.deepEqual(gh.calls.find((c) => c[0] === 'createBranch'), ['createBranch', 'vercel-sandbox/x', snap.base]);
  assert.equal(gh.calls.find((c) => c[0] === 'openPr')[1].base, 'main');
});

test('publishSnapshot refuses an existing branch and a branch outside the prefix', async () => {
  await assert.rejects(publishSnapshot({ github: fakeGithub({ exists: true }), repo: 'o/r', branch: 'vercel-sandbox/x', snapshot: snap, title: 't' }), /already exists/);
  await assert.rejects(publishSnapshot({ github: fakeGithub(), repo: 'o/r', branch: 'main', snapshot: snap, title: 't' }), /must start with/);
});

test('githubClient sends the token, maps 404 on a ref to false, and surfaces GraphQL errors', async () => {
  const seen = [];
  const fetch = async (url, init) => {
    seen.push([init.method, url, init.headers.Authorization]);
    if (url.endsWith('/git/ref/heads/vercel-sandbox/x')) return new Response('{"message":"Not Found"}', { status: 404 });
    if (url.endsWith('/graphql')) return new Response(JSON.stringify({ errors: [{ message: 'expectedHeadOid mismatch' }] }), { status: 200 });
    return new Response('{}', { status: 200 });
  };
  const gh = githubClient({ token: 'tkn', fetch });
  assert.equal(await gh.branchExists('o/r', 'vercel-sandbox/x'), false);
  await assert.rejects(gh.commitOnBranch({}), /expectedHeadOid mismatch/);
  assert.ok(seen.every(([, , auth]) => auth === 'Bearer tkn'));
});
