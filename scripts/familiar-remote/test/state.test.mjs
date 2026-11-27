import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { addressOf, familiarStore, registerSession, requestQueue } from '../lib/state.mjs';
import { findInCatalog, parseModelSpec, resolveModel } from '../lib/model.mjs';

test('requests queue in order and are taken once', () => {
  const root = mkdtempSync(join(tmpdir(), 'rf-state-'));
  try {
    const q = requestQueue(root);
    q.add({ name: 'b-one', repo: 'o/r', brief: 'x' });
    q.add({ name: 'a-two', repo: 'o/r', brief: 'y' });
    assert.deepEqual(q.take().map((r) => r.name), ['b-one', 'a-two']);
    assert.deepEqual(q.take(), []);
    assert.throws(() => q.add({ name: '../x' }), /name must match/);
    const s = familiarStore(root);
    s.put({ name: 'fam', status: 'running' });
    assert.equal(s.update('fam', { status: 'done' }).status, 'done');
    assert.equal(s.get('../etc'), null);
    assert.equal(s.list().length, 1);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test('registry record follows pi-post: address scheme, pid only while live', () => {
  const root = mkdtempSync(join(tmpdir(), 'rf-post-'));
  try {
    const address = addressOf('wrun_123');
    assert.match(address, /^s-[0-9a-f]{12}$/);
    registerSession({ root, address, sessionId: 'wrun_123', name: 'rfam-x', cwd: 'github.com/o/r', parent: 's-parent', startedAt: 1, pid: 42, now: 5 });
    const live = JSON.parse(readFileSync(join(root, 'registry', `${address}.json`), 'utf8'));
    assert.deepEqual(live, { v: 1, address, sessionId: 'wrun_123', name: 'rfam-x', cwd: 'github.com/o/r', startedAt: 1, lastSeen: 5, parent: 's-parent', pid: 42, kind: 'remote-familiar' });
    registerSession({ root, address, sessionId: 'wrun_123', name: 'rfam-x', cwd: 'github.com/o/r', startedAt: 1, live: false, now: 9 });
    assert.equal(JSON.parse(readFileSync(join(root, 'registry', `${address}.json`), 'utf8')).pid, undefined);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test('model specs: aliases, effort, catalog first, pinned fallback', () => {
  assert.deepEqual(parseModelSpec('fable'), { id: 'anthropic/claude-fable-5.2', thinkingLevel: 'high' });
  assert.deepEqual(parseModelSpec('openai/gpt-6.2-astra:xhigh'), { id: 'openai/gpt-6.2-astra', thinkingLevel: 'xhigh' });
  assert.throws(() => parseModelSpec('nope'), /alias/);
  assert.throws(() => parseModelSpec('a/b:loud'), /unknown effort/);
  const catalog = { 'anthropic-messages': { 'chat:openai/gpt-6.2-sol': { id: 'openai/gpt-6.2-sol', api: 'anthropic-messages' } } };
  assert.equal(findInCatalog(catalog, 'openai/gpt-6.2-sol').api, 'anthropic-messages');
  assert.equal(resolveModel('sol', { catalog }).spec, 'openai/gpt-6.2-sol:high');
  assert.equal(resolveModel('opus', { catalog, pinned: (id) => ({ id, from: 'pinned' }) }).model.from, 'pinned');
  assert.throws(() => resolveModel('opus', { catalog }), /no gateway model/);
});
