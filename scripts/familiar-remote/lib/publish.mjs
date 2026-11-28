// The publish path of a remote familiar. The driver, not the VM, takes the
// sandbox's working tree as a snapshot (every changed file with its content),
// and after the user approves that exact snapshot it commits it on a side
// branch with GraphQL createCommitOnBranch, so GitHub signs the commit, and
// opens the PR. No write credential ever reaches the VM.

import { createHash } from 'node:crypto';

const q = (s) => `'${String(s).replaceAll("'", "'\\''")}'`;
const SHA = /^[0-9a-f]{40}$/;
export const BRANCH_PREFIX = 'vercel-sandbox/';
export const REPO = /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/;

/** The VM script that stages the working tree against the clone's base in a scratch index and prints the raw diff. */
export function stageScript(repoDir) {
  return [
    'set -eo pipefail',
    `cd ${q(repoDir)}`,
    "git config --global --add safe.directory '*' >/dev/null 2>&1 || true",
    'base=$(git rev-parse --verify -q origin/HEAD || true)',
    '[ -n "$base" ] || { echo "NO_BASE: origin/HEAD is not set; clone the repository with git clone" >&2; exit 3; }',
    'idx=/tmp/rf-index; rm -f "$idx"',
    'GIT_INDEX_FILE=$idx git read-tree "$base"',
    'GIT_INDEX_FILE=$idx git add -A',
    'GIT_INDEX_FILE=$idx git diff --cached --binary --no-renames "$base" > /tmp/rf.patch',
    'printf "BASE %s\\n" "$base"',
    'GIT_INDEX_FILE=$idx git diff --cached --raw --no-renames --no-abbrev -z "$base" | base64 -w0',
  ].join('\n');
}

/** Parse `git diff --raw -z` output: `:old new oldsha newsha S\0path\0` records. */
export function parseRaw(raw) {
  const parts = raw.split('\0');
  const out = [];
  for (let i = 0; i + 1 < parts.length; i += 2) {
    const head = parts[i].replace(/^\n/, '');
    if (!head) continue;
    const m = /^:(\d{6}) (\d{6}) ([0-9a-f]{40}) ([0-9a-f]{40}) ([AMDT])$/.exec(head);
    if (!m) throw new Error(`unexpected raw diff record: ${head.slice(0, 120)}`);
    out.push({ oldMode: m[1], newMode: m[2], oldSha: m[3], newSha: m[4], status: m[5], path: parts[i + 1] });
  }
  return out;
}

export function checkPath(p) {
  if (!p || p.startsWith('/') || p.split('/').some((x) => x === '..' || x === '.git') || /[\0\n]/.test(p)) throw new Error(`unsafe path in diff: ${JSON.stringify(p)}`);
}

export function digestOf(base, files) {
  const h = createHash('sha256').update(base);
  for (const f of [...files].sort((a, b) => a.path.localeCompare(b.path))) {
    h.update(`\0${f.status}\0${f.path}\0`);
    if (f.content) h.update(createHash('sha256').update(f.content).digest('hex'));
  }
  return h.digest('hex');
}

/**
 * Take the VM's working tree as a snapshot.
 * @param {{ run: (script: string) => Promise<{ code: number, out: string }>, readFile: (path: string) => Promise<Buffer> }} vm
 * @returns {Promise<{ base: string, files: { path: string, status: 'A'|'M'|'D', mode: string, content?: Buffer }[], patch: string, notes: string[], digest: string }>}
 */
export async function takeSnapshot(vm, repoDir) {
  const staged = await vm.run(stageScript(repoDir));
  if (staged.code !== 0) throw new Error(`staging the working tree failed (${staged.code}): ${staged.out.slice(-800)}`);
  const lines = staged.out.trim().split('\n');
  const baseLine = lines.find((l) => l.startsWith('BASE '));
  const base = baseLine?.slice(5).trim();
  if (!SHA.test(base ?? '')) throw new Error('could not read the base commit');
  const raw = Buffer.from(lines.at(-1) === baseLine ? '' : lines.at(-1), 'base64').toString('utf8');
  const records = parseRaw(raw);
  const files = [];
  const notes = [];
  for (const r of records) {
    checkPath(r.path);
    if ([r.oldMode, r.newMode].some((m) => m === '120000' || m === '160000')) throw new Error(`${r.path}: symlinks and submodules cannot be published`);
    if (r.status === 'D') {
      files.push({ path: r.path, status: 'D', mode: r.oldMode });
      continue;
    }
    if (r.newMode === '100755' && r.oldMode !== '100755') notes.push(`${r.path}: the executable bit is lost (createCommitOnBranch cannot set it)`);
    const blob = await vm.run(`cd ${q(repoDir)} && git cat-file blob ${r.newSha} | base64 -w0`);
    if (blob.code !== 0) throw new Error(`reading ${r.path} failed: ${blob.out.slice(-300)}`);
    files.push({ path: r.path, status: r.status === 'T' ? 'M' : r.status, mode: r.newMode, content: Buffer.from(blob.out.trim(), 'base64') });
  }
  const patch = (await vm.readFile('/tmp/rf.patch')).toString('utf8');
  return { base, files, patch, notes, digest: digestOf(base, files) };
}

export function summarize(snapshot) {
  const count = (s) => snapshot.files.filter((f) => f.status === s).length;
  return `${snapshot.files.length} files (${count('A')} added, ${count('M')} modified, ${count('D')} deleted)`;
}

/** A small GitHub client over fetch, with the user's token, on the driver only. */
export function githubClient({ token, fetch = globalThis.fetch, api = 'https://api.github.com' }) {
  const call = async (method, path, body) => {
    const res = await fetch(`${api}${path}`, {
      method,
      headers: { Authorization: `Bearer ${token}`, Accept: 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28', ...(body ? { 'Content-Type': 'application/json' } : {}) },
      body: body ? JSON.stringify(body) : undefined,
    });
    const text = await res.text();
    let json;
    try { json = text ? JSON.parse(text) : {}; } catch { json = { message: text }; }
    if (!res.ok) throw new Error(`GitHub ${method} ${path}: ${res.status} ${json.message ?? ''}`.trim());
    return json;
  };
  return {
    repo: (repo) => call('GET', `/repos/${repo}`),
    commit: (repo, sha) => call('GET', `/repos/${repo}/commits/${sha}`),
    branchExists: async (repo, branch) => {
      try { await call('GET', `/repos/${repo}/git/ref/heads/${branch}`); return true; }
      catch (e) { if (/: 404\b/.test(e.message)) return false; throw e; }
    },
    createBranch: (repo, branch, sha) => call('POST', `/repos/${repo}/git/refs`, { ref: `refs/heads/${branch}`, sha }),
    commitOnBranch: async (input) => {
      const query = 'mutation($input: CreateCommitOnBranchInput!) { createCommitOnBranch(input: $input) { commit { oid url signature { isValid } } } }';
      const res = await call('POST', '/graphql', { query, variables: { input } });
      if (res.errors?.length) throw new Error(`createCommitOnBranch: ${res.errors.map((e) => e.message).join('; ')}`);
      return res.data.createCommitOnBranch.commit;
    },
    openPr: (repo, pr) => call('POST', `/repos/${repo}/pulls`, pr),
    pr: (repo, number) => call('GET', `/repos/${repo}/pulls/${number}`),
  };
}

/**
 * Publish an approved snapshot: side branch at the base, one signed commit, a PR.
 * @returns {Promise<{ branch: string, commit: string, verified: boolean, pr: string, number: number }>}
 */
export async function publishSnapshot({ github, repo, branch, snapshot, title, body }) {
  if (!REPO.test(repo)) throw new Error(`bad repo ${repo}`);
  if (!branch.startsWith(BRANCH_PREFIX)) throw new Error(`branch must start with ${BRANCH_PREFIX}`);
  const info = await github.repo(repo);
  await github.commit(repo, snapshot.base);
  if (await github.branchExists(repo, branch)) throw new Error(`branch ${branch} already exists on ${repo}`);
  await github.createBranch(repo, branch, snapshot.base);
  const commit = await github.commitOnBranch({
    branch: { repositoryNameWithOwner: repo, branchName: branch },
    expectedHeadOid: snapshot.base,
    message: { headline: title, ...(body ? { body } : {}) },
    fileChanges: {
      additions: snapshot.files.filter((f) => f.status !== 'D').map((f) => ({ path: f.path, contents: f.content.toString('base64') })),
      deletions: snapshot.files.filter((f) => f.status === 'D').map((f) => ({ path: f.path })),
    },
  });
  const pr = await github.openPr(repo, { title, head: branch, base: info.default_branch, body: body ?? '' });
  return { branch, commit: commit.oid, verified: commit.signature?.isValid === true, pr: pr.html_url, number: pr.number, ...publishedState(snapshot) };
}

/** What a later update needs to know about the branch: the base and each changed path. */
export function publishedState(snapshot) {
  return { base: snapshot.base, digest: snapshot.digest, files: snapshot.files.map((f) => ({ path: f.path, status: f.status })) };
}

/**
 * The file changes that take the branch from the last published snapshot to
 * this one. Both are diffs against the same base, so a path the familiar has
 * put back goes back to the base: deleted when the last one added it, else
 * restored from `baseContent` (read from the VM, `restorePaths`).
 */
export function updateChanges(previous, snapshot, baseContent = new Map()) {
  if (previous.base !== snapshot.base) throw new Error(`the sandbox clone moved from ${previous.base.slice(0, 9)} to ${snapshot.base.slice(0, 9)}; updating a PR across a new base is not supported`);
  if (previous.digest === snapshot.digest) throw new Error('nothing changed since the last publish');
  const was = new Map(previous.files.map((f) => [f.path, f.status]));
  const now = new Set(snapshot.files.map((f) => f.path));
  const additions = [];
  const deletions = [];
  for (const f of snapshot.files) {
    if (f.status === 'D') { if (was.get(f.path) !== 'D') deletions.push({ path: f.path }); }
    else additions.push({ path: f.path, contents: f.content.toString('base64') });
  }
  for (const [path, status] of was) {
    if (now.has(path)) continue;
    if (status === 'A') deletions.push({ path });
    else {
      const content = baseContent.get(path);
      if (!content) throw new Error(`${path}: no base content to restore`);
      additions.push({ path, contents: content.toString('base64') });
    }
  }
  return { additions, deletions };
}

/** Paths the last publish changed that this snapshot leaves at the base, and were not added: they need their base content. */
export function restorePaths(previous, snapshot) {
  const now = new Set(snapshot.files.map((f) => f.path));
  return previous.files.filter((f) => !now.has(f.path) && f.status !== 'A').map((f) => f.path);
}

export async function readBaseFiles(vm, repoDir, base, paths) {
  const out = new Map();
  for (const p of paths) {
    checkPath(p);
    const r = await vm.run(`cd ${q(repoDir)} && git cat-file blob ${q(`${base}:${p}`)} | base64 -w0`);
    if (r.code !== 0) throw new Error(`reading ${p} at the base failed: ${r.out.slice(-300)}`);
    out.set(p, Buffer.from(r.out.trim(), 'base64'));
  }
  return out;
}

/** Push an approved follow-up snapshot onto the familiar's open PR as one more signed commit. */
export async function updatePublished({ github, repo, previous, snapshot, title, body, baseContent }) {
  if (!REPO.test(repo)) throw new Error(`bad repo ${repo}`);
  const pr = await github.pr(repo, previous.number);
  if (pr.state !== 'open') throw new Error(`PR #${previous.number} is ${pr.merged_at ? 'merged' : pr.state}; a closed PR cannot take more commits`);
  const fileChanges = updateChanges(previous, snapshot, baseContent);
  const commit = await github.commitOnBranch({
    branch: { repositoryNameWithOwner: repo, branchName: previous.branch },
    expectedHeadOid: previous.commit,
    message: { headline: title, ...(body ? { body } : {}) },
    fileChanges,
  });
  return { ...previous, commit: commit.oid, verified: commit.signature?.isValid === true, ...publishedState(snapshot), commits: [...(previous.commits ?? [previous.commit]), commit.oid] };
}
