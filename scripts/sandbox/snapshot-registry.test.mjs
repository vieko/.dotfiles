import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { findSnapshot, listSnapshots, recordSnapshot, registryPath, repoSlug } from './snapshot-registry.mjs';

test('repoSlug reads https and ssh GitHub remotes', () => {
  assert.equal(repoSlug('https://github.com/vercel/gtm.git'), 'vercel/gtm');
  assert.equal(repoSlug('git@github.com:vercel/gtm.git'), 'vercel/gtm');
  assert.equal(repoSlug('https://github.com/vercel/gtm'), 'vercel/gtm');
  assert.equal(repoSlug('https://example.com/vercel/gtm.git'), null);
});

test('registryPath honours XDG_STATE_HOME and falls back to ~/.local/state', () => {
  assert.equal(registryPath({ XDG_STATE_HOME: '/x' }, '/h'), '/x/anvil-sandbox/snapshots.json');
  assert.equal(registryPath({}, '/h'), '/h/.local/state/anvil-sandbox/snapshots.json');
});

test('record, list and find: newest matching snapshot wins, same id replaces', async () => {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'snapshot-registry-'));
  const file = path.join(dir, 'nested', 'snapshots.json');
  assert.deepEqual(await listSnapshots(file), []);
  await recordSnapshot({ snapshotId: 'a', repo: 'acme/repo', lockfileHash: 'h1', builtAt: '2026-01-01T00:00:00Z' }, file);
  await recordSnapshot({ snapshotId: 'b', repo: 'acme/repo', lockfileHash: 'h1', builtAt: '2026-01-02T00:00:00Z' }, file);
  await recordSnapshot({ snapshotId: 'a', repo: 'acme/repo', lockfileHash: 'h2', builtAt: '2026-01-03T00:00:00Z' }, file);
  const all = await listSnapshots(file);
  assert.deepEqual(all.map(r => r.snapshotId), ['b', 'a']);
  assert.equal(findSnapshot(all, 'acme/repo', 'h1')?.snapshotId, 'b');
  assert.equal(findSnapshot(all, 'acme/repo', 'h2')?.snapshotId, 'a');
  assert.equal(findSnapshot(all, 'acme/other', 'h1'), null);
  await fs.rm(dir, { recursive: true });
});

// Two unrelated repos can share a lockfile hash by accident (an empty lockfile, a trivial one);
// that is not evidence the snapshot was built for both, so findSnapshot never crosses repos
// (anvil#63).
test('findSnapshot ignores a record of another repo even with a matching lockfile hash', () => {
  const records = [
    { snapshotId: 'shared-hash-other-repo', repo: 'acme/other', lockfileHash: 'shared', builtAt: '2026-02-01T00:00:00Z' },
    { snapshotId: 'shared-hash-this-repo', repo: 'acme/repo', lockfileHash: 'shared', builtAt: '2026-01-01T00:00:00Z' },
  ];
  assert.equal(findSnapshot(records, 'acme/repo', 'shared')?.snapshotId, 'shared-hash-this-repo');
  assert.equal(findSnapshot(records, 'acme/missing', 'shared'), null);
});
