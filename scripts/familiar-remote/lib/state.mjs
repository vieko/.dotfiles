// Driver state on disk, and the pi-post registry record that makes each remote
// familiar a session the Sigil overview lists (and a pi-post target, for
// steering in a later slice).
//
// ~/.local/state/remote-familiars/ (REMOTE_FAMILIARS_DIR)
//   requests/<name>.json    start requests the CLI writes and the driver takes
//   familiars/<name>.json   one record per familiar, rewritten in place
//   world/                  world-local data (the sessions' event logs)
//   driver.json             the running driver's pid and heartbeat

import { createHash } from 'node:crypto';
import { mkdirSync, readdirSync, readFileSync, renameSync, rmSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

export const NAME = /^[a-z0-9][a-z0-9-]{1,47}$/;

export function stateDir(env = process.env) {
  return env.REMOTE_FAMILIARS_DIR || join(homedir(), '.local', 'state', 'remote-familiars');
}
export const paths = (root = stateDir()) => ({
  root,
  requests: join(root, 'requests'),
  familiars: join(root, 'familiars'),
  world: join(root, 'world'),
  driver: join(root, 'driver.json'),
});

export function writeJson(path, value) {
  const tmp = `${path}.${process.pid}.tmp`;
  writeFileSync(tmp, `${JSON.stringify(value, null, 2)}\n`, { mode: 0o600 });
  renameSync(tmp, path);
}
export function readJson(path) {
  try { return JSON.parse(readFileSync(path, 'utf8')); } catch { return null; }
}

/** pi-post's address scheme (pi-post src/address.ts), over the durable session id. */
export function addressOf(sessionId) {
  return `s-${createHash('sha256').update(`session\0${sessionId}`).digest('hex').slice(0, 12)}`;
}

export function familiarStore(root = stateDir()) {
  const p = paths(root);
  mkdirSync(p.familiars, { recursive: true, mode: 0o700 });
  const file = (name) => join(p.familiars, `${name}.json`);
  return {
    get: (name) => (NAME.test(name) ? readJson(file(name)) : null),
    put: (rec) => writeJson(file(rec.name), rec),
    update(name, patch) {
      const rec = this.get(name);
      if (!rec) return null;
      const next = { ...rec, ...patch, updatedAt: Date.now() };
      writeJson(file(name), next);
      return next;
    },
    list: () => readdirSync(p.familiars).filter((f) => f.endsWith('.json')).map((f) => readJson(join(p.familiars, f))).filter(Boolean),
  };
}

/** Requests the CLI wrote, oldest first. Taking one removes its file. */
export function requestQueue(root = stateDir()) {
  const p = paths(root);
  mkdirSync(p.requests, { recursive: true, mode: 0o700 });
  return {
    add(req) {
      if (!NAME.test(req.name)) throw new Error(`name must match ${NAME}`);
      writeJson(join(p.requests, `${req.name}.json`), { ...req, queuedAt: Date.now() });
    },
    take() {
      const out = [];
      for (const f of readdirSync(p.requests).filter((n) => n.endsWith('.json')).sort()) {
        const path = join(p.requests, f);
        const req = readJson(path);
        rmSync(path, { force: true });
        if (req) out.push(req);
      }
      return out.sort((a, b) => (a.queuedAt ?? 0) - (b.queuedAt ?? 0));
    },
  };
}

export function postRoot(env = process.env) {
  return env.PI_POST_DIR || join(homedir(), '.pi', 'agent', 'post');
}

/** Write or refresh the familiar's pi-post registry record. `live: false` drops the pid, as pi-post does on shutdown. */
export function registerSession({ root = postRoot(), address, sessionId, name, cwd, parent, startedAt, live = true, pid = process.pid, now = Date.now() }) {
  const dir = join(root, 'registry');
  mkdirSync(dir, { recursive: true, mode: 0o700 });
  const record = { v: 1, address, sessionId, name, cwd, startedAt, lastSeen: now, ...(parent ? { parent } : {}), ...(live ? { pid } : {}), kind: 'remote-familiar' };
  writeJson(join(dir, `${address}.json`), record);
  return record;
}
