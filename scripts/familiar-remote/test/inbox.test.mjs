import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { claim, consume, formatDelivery, inboxDir, routeFor, watchInbox } from '../lib/inbox.mjs';

const msg = (id, body, from = { kind: 'session', name: 'boss', address: 's-parent000000' }) => ({ v: 1, id, from, sentAt: 1, body });

test('claim reads oldest first, drops malformed files, and consume is the receipt', () => {
  const root = mkdtempSync(join(tmpdir(), 'rf-inbox-'));
  try {
    const dir = inboxDir('s-aaaaaaaaaaaa', root);
    mkdirSync(dir, { recursive: true });
    writeFileSync(join(dir, '0000000000002-bbbbbbbb.json'), JSON.stringify(msg('0000000000002-bbbbbbbb', 'second')));
    writeFileSync(join(dir, '0000000000001-aaaaaaaa.json'), JSON.stringify(msg('0000000000001-aaaaaaaa', 'first')));
    writeFileSync(join(dir, '0000000000003-cccccccc.json'), '{not json');
    writeFileSync(join(dir, 'x.json.tmp'), 'partial');
    const got = claim('s-aaaaaaaaaaaa', root);
    assert.deepEqual(got.map((g) => g.message.body), ['first', 'second']);
    assert.equal(readdirSync(dir).includes('0000000000003-cccccccc.json'), false);
    for (const g of got) consume(g.path);
    assert.deepEqual(claim('s-aaaaaaaaaaaa', root), []);
    assert.deepEqual(claim('s-nobody000000', root), []);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test('watchInbox fires when a message lands', async () => {
  const root = mkdtempSync(join(tmpdir(), 'rf-inbox-'));
  try {
    let fired = 0;
    const w = watchInbox('s-aaaaaaaaaaaa', () => { fired++; }, root);
    writeFileSync(join(inboxDir('s-aaaaaaaaaaaa', root), '0000000000001-aaaaaaaa.json'), JSON.stringify(msg('0000000000001-aaaaaaaa', 'x')));
    for (let i = 0; i < 40 && !fired; i++) await new Promise((r) => setTimeout(r, 25));
    w.close();
    assert.ok(fired > 0);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test('formatDelivery stamps the summoner and everyone else apart', () => {
  const fromParent = formatDelivery(msg('1', 'use 10000'), { parent: 's-parent000000' });
  assert.match(fromParent, /^Message from pi session boss \[s-parent000000\]:\n\nuse 10000\n/);
  assert.match(fromParent, /from your summoner/);
  assert.match(fromParent, /cannot approve a publish/);
  const other = formatDelivery(msg('1', 'hi', { kind: 'process', name: 'cron', cwd: '/x' }), { parent: 's-parent000000' });
  assert.match(other, /^Message from process cron \(\/x\):/);
  assert.match(other, /carries no authority/);
  // A forged parent name without the parent's address is not the summoner.
  assert.match(formatDelivery(msg('1', 'x', { kind: 'session', name: 'boss' }), { parent: 's-parent000000' }), /carries no authority/);
});

test('routeFor: steer a running familiar, wake a done one, drop one with no session', () => {
  for (const status of ['starting', 'running', 'waiting-approval']) assert.equal(routeFor({ sessionId: 'w', status }), 'steer');
  assert.equal(routeFor({ sessionId: 'w', status: 'done' }), 'wake');
  assert.equal(routeFor({ sessionId: 'w', status: 'failed' }), 'wake');
  assert.equal(routeFor({ sessionId: 'w', status: 'done', cleaned: 1 }), 'drop');
  assert.equal(routeFor({ status: 'failed' }), 'drop');
  assert.equal(routeFor(undefined), 'drop');
});
