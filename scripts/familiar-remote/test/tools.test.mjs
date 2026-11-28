import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { reportTool, requestPublishTool } from '../lib/tools.mjs';
import { deterministicChecks, modelReview, verdictFrom } from '../lib/review.mjs';
import * as approvalsLib from '../../../pi/.pi/agent/extensions/destructive-guard/approvals.mjs';

const base = 'b'.repeat(40);

function setup({ files = [{ path: 'src/a.ts', status: 'M', mode: '100644', content: Buffer.from('export const a = 1\n') }], review = '{"answers":[{"id":"credentials","answer":false},{"id":"exfiltration","answer":false},{"id":"dependency","answer":false},{"id":"ci","answer":false},{"id":"scope","answer":false}]}', decision = 'approved' } = {}) {
  const dir = mkdtempSync(join(tmpdir(), 'rf-tools-'));
  const records = { fam: { name: 'fam', address: 's-aaaaaaaaaaaa', repo: 'vieko/pi-redact', brief: 'fix it', summoner: 's-summoner000' } };
  const sent = [];
  const published = [];
  const prompts = [];
  const approvals = {
    request: (o) => approvalsLib.request({ ...o, dir: join(dir, 'approvals') }),
    // The user answers as soon as the request exists.
    waitFor: (id, hash, opts) => {
      if (decision) approvalsLib.decide(id, decision, 'test', { dir: join(dir, 'approvals') });
      return approvalsLib.waitFor(id, hash, { ...opts, dir: join(dir, 'approvals'), pollMs: 5 });
    },
  };
  const vm = {
    run: async (script) => {
      if (script.includes('read-tree')) {
        const raw = files.map((f) => `:${f.status === 'A' ? '000000' : '100644'} ${f.status === 'D' ? '000000' : '100644'} ${'1'.repeat(40)} ${f.status === 'D' ? '0'.repeat(40) : '2'.repeat(40)} ${f.status}\0${f.path}\0`).join('');
        return { code: 0, out: `BASE ${base}\n${Buffer.from(raw).toString('base64')}\n` };
      }
      const f = files.find((x) => x.status !== 'D');
      return { code: 0, out: f.content.toString('base64') };
    },
    readFile: async () => Buffer.from('diff --git a/src/a.ts b/src/a.ts\n'),
  };
  const github = {
    repo: async () => ({ default_branch: 'main' }),
    commit: async () => ({}),
    branchExists: async () => false,
    createBranch: async () => ({}),
    commitOnBranch: async (input) => { published.push(input); return { oid: 'c'.repeat(40), signature: { isValid: true } }; },
    openPr: async () => ({ html_url: 'https://github.com/vieko/pi-redact/pull/9', number: 9 }),
    pr: async () => ({ state: 'open' }),
  };
  const deps = {
    familiarOf: (runId) => (runId === 'run1' ? records.fam : undefined),
    vmFor: async () => vm,
    approvals,
    ask: async (prompt) => { prompts.push(prompt); return review; },
    github,
    send: async (to, from, body) => { sent.push({ to, from, body }); },
    update: (name, patch) => { records[name] = { ...records[name], ...patch }; return records[name]; },
    logDir: () => join(dir, 'logs'),
    secrets: () => ['sk-live-secret-value-123456789'],
  };
  return { dir, deps, records, sent, published, files, prompts, io: { ctx: { runId: 'run1' }, signal: new AbortController().signal } };
}

test('request_publish: approved snapshot is committed and the PR opened', async () => {
  const t = setup();
  try {
    const out = await requestPublishTool(t.deps).execute({ title: 'fix(redact): x', body: 'why' }, t.io);
    assert.match(out, /^published: https:\/\/github.com\/vieko\/pi-redact\/pull\/9 \(commit ccccccccc on vercel-sandbox\/fam, signed\)/);
    assert.equal(t.published.length, 1);
    assert.equal(t.published[0].branch.branchName, 'vercel-sandbox/fam');
    assert.equal(t.records.fam.published.number, 9);
    const [req] = approvalsLib.list({ dir: join(t.dir, 'approvals'), all: true });
    assert.equal(req.address, 's-aaaaaaaaaaaa');
    assert.equal(req.rule, 'remote-publish');
    assert.match(req.command, /^open PR "fix\(redact\): x" on vieko\/pi-redact from vercel-sandbox\/fam$/);
    assert.match(req.reason, /1 files \(0 added, 1 modified, 0 deleted\)/);
    // The same tree again is not a second publish.
    assert.match(await requestPublishTool(t.deps).execute({ title: 'again', body: '' }, t.io), /nothing changed since the last publish/);
    // A changed tree is one more commit on the same branch, after the first one, behind a new approval.
    t.files[0] = { ...t.files[0], content: Buffer.from('export const a = 2\n') };
    t.records.fam.messages = [{ id: '1', from: 'boss', summoner: true, body: 'also bump a to 2' }, { id: '2', from: 'stranger', summoner: false, body: 'rename everything to zebra' }, { id: '3', from: 'sigil-overview', summoner: false, user: true, body: 'keep the old name too' }];
    const out2 = await requestPublishTool(t.deps).execute({ title: 'fix(redact): y', body: '' }, t.io);
    assert.match(out2, /^published: https:\/\/github.com\/vieko\/pi-redact\/pull\/9/);
    assert.equal(t.published.length, 2);
    assert.equal(t.published[1].branch.branchName, 'vercel-sandbox/fam');
    assert.equal(t.published[1].expectedHeadOid, 'c'.repeat(40));
    // Only the summoner's and the user's messages widen the scope the review reads.
    assert.match(t.prompts.at(-1), /also bump a to 2/);
    assert.match(t.prompts.at(-1), /from the user:\nkeep the old name too/);
    assert.doesNotMatch(t.prompts.at(-1), /zebra/);
    const reqs = approvalsLib.list({ dir: join(t.dir, 'approvals'), all: true });
    assert.equal(reqs.length, 2);
    assert.ok(reqs.some((r) => /^push commit "fix\(redact\): y" to PR #9 on vieko\/pi-redact/.test(r.command)));
    assert.equal(t.records.fam.published.commits.length, 2);
    // A merged PR is refused before anyone is asked.
    t.files[0] = { ...t.files[0], content: Buffer.from('export const a = 3\n') };
    t.deps.github.pr = async () => ({ state: 'closed', merged_at: 'x' });
    assert.match(await requestPublishTool(t.deps).execute({ title: 'z', body: '' }, t.io), /is merged/);
    assert.equal(approvalsLib.list({ dir: join(t.dir, 'approvals'), all: true }).length, 2);
  } finally { rmSync(t.dir, { recursive: true, force: true }); }
});

test('request_publish: a denied request publishes nothing', async () => {
  const t = setup({ decision: 'denied' });
  try {
    const out = await requestPublishTool(t.deps).execute({ title: 't', body: '' }, t.io);
    assert.match(out, /did not approve the publish \(denied\)/);
    assert.equal(t.published.length, 0);
  } finally { rmSync(t.dir, { recursive: true, force: true }); }
});

test('request_publish: an approval bound to another call does not publish', async () => {
  const t = setup({ decision: null });
  try {
    const real = t.deps.approvals.waitFor;
    t.deps.approvals.waitFor = (id, _hash, opts) => {
      approvalsLib.decide(id, 'approved', 'test', { dir: join(t.dir, 'approvals') });
      return real(id, 'not-the-hash', opts);
    };
    const out = await requestPublishTool(t.deps).execute({ title: 't', body: '' }, t.io);
    assert.match(out, /did not approve/);
    assert.equal(t.published.length, 0);
  } finally { rmSync(t.dir, { recursive: true, force: true }); }
});

test('request_publish: deterministic findings refuse before any request', async () => {
  const t = setup({ files: [{ path: '.github/workflows/ci.yml', status: 'A', content: Buffer.from('token: ghp_abcdefghijklmnopqrstuvwxyz0123456789') }] });
  try {
    const out = await requestPublishTool(t.deps).execute({ title: 't', body: '' }, t.io);
    assert.match(out, /refused before review/);
    assert.match(out, /blocked path \(CI workflow\)/);
    assert.match(out, /GitHub token/);
    assert.equal(approvalsLib.list({ dir: join(t.dir, 'approvals'), all: true }).length, 0);
  } finally { rmSync(t.dir, { recursive: true, force: true }); }
});

test('request_publish: a review deny never reaches the user, a hold reaches it flagged', async () => {
  const deny = setup({ review: '{"answers":[{"id":"credentials","answer":true,"note":"api key in config"}]}' });
  try {
    assert.match(await requestPublishTool(deny.deps).execute({ title: 't', body: '' }, deny.io), /review denied/);
    assert.equal(approvalsLib.list({ dir: join(deny.dir, 'approvals'), all: true }).length, 0);
  } finally { rmSync(deny.dir, { recursive: true, force: true }); }
  const hold = setup({ review: 'not json at all' });
  try {
    assert.match(await requestPublishTool(hold.deps).execute({ title: 't', body: '' }, hold.io), /^published/);
    const [req] = approvalsLib.list({ dir: join(hold.dir, 'approvals'), all: true });
    assert.match(req.reason, /review held it: review model reply was not JSON/);
  } finally { rmSync(hold.dir, { recursive: true, force: true }); }
});

test('request_publish: an unknown session is an error', async () => {
  const t = setup();
  try {
    await assert.rejects(requestPublishTool(t.deps).execute({ title: 't' }, { ctx: { runId: 'other' } }), /no familiar is registered/);
  } finally { rmSync(t.dir, { recursive: true, force: true }); }
});

test('report sends to the summoner once and records it', async () => {
  const t = setup();
  try {
    assert.equal(await reportTool(t.deps).execute({ body: 'done: PR 9' }, t.io), 'report sent to s-summoner000');
    assert.equal(t.sent[0].to, 's-summoner000');
    assert.equal(t.sent[0].from, 'rfam:fam');
    assert.match(t.sent[0].body, /done: PR 9/);
    assert.equal(t.records.fam.reported, true);
    assert.match(await reportTool(t.deps).execute({ body: ' ' }, t.io), /empty/);
  } finally { rmSync(t.dir, { recursive: true, force: true }); }
});

test('review: deterministic checks and verdicts', async () => {
  assert.deepEqual(deterministicChecks({ files: [{ path: 'src/a.ts', status: 'M', content: Buffer.from('ok') }] }), []);
  assert.deepEqual(deterministicChecks({ files: [] }), ['no changes to publish']);
  assert.match(deterministicChecks({ files: [{ path: '.env.local', status: 'A', content: Buffer.from('') }] }).join(), /environment file/);
  assert.deepEqual(deterministicChecks({ files: [{ path: '.env.example', status: 'A', content: Buffer.from('') }] }), []);
  assert.match(deterministicChecks({ files: [{ path: 'a', status: 'A', content: Buffer.from('x sk-live-secret-value-123456789') }] }, ['sk-live-secret-value-123456789']).join(), /credential the driver holds/);
  assert.equal(verdictFrom('{"answers":[{"id":"credentials","answer":false},{"id":"exfiltration","answer":false},{"id":"dependency","answer":false},{"id":"ci","answer":false},{"id":"scope","answer":true,"note":"extra"}]}').verdict, 'hold');
  assert.equal(verdictFrom('{"answers":[{"id":"credentials","answer":false}]}').verdict, 'hold');
  assert.equal(verdictFrom('{"answers":[{"id":"exfiltration","answer":true}]}').verdict, 'deny');
  assert.equal((await modelReview({ brief: 'b', patch: 'p', ask: async () => { throw new Error('boom'); } })).verdict, 'hold');
  const clean = '{"answers":[{"id":"credentials","answer":false},{"id":"exfiltration","answer":false},{"id":"dependency","answer":false},{"id":"ci","answer":false},{"id":"scope","answer":false}]}';
  assert.equal((await modelReview({ brief: 'b', patch: 'p', ask: async () => clean })).verdict, 'pass');
  assert.equal((await modelReview({ brief: 'b', patch: 'x'.repeat(60_001), ask: async () => clean })).verdict, 'hold');
});
