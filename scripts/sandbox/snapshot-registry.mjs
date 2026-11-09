// Local record of the snapshots build-snapshot.mjs has produced, so the controller can tell
// before it creates a sandbox whether the approved snapshot still matches the fork's lockfile,
// and pick or rebuild one when it does not (anvil#59). Snapshot ids are resource ids: this file
// lives in user state, never in a repo.
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';

export function registryPath(env = process.env, homeDir = os.homedir()) {
  const xdg = env.XDG_STATE_HOME?.trim();
  return path.join(xdg || path.join(homeDir, '.local/state'), 'anvil-sandbox', 'snapshots.json');
}

/** `vercel/gtm` from any https or ssh GitHub remote; null when the url is not GitHub-shaped. */
export function repoSlug(url) {
  const m = /github\.com[/:]([^/]+)\/([^/]+?)(?:\.git)?\/?$/.exec(String(url ?? ''));
  return m ? `${m[1]}/${m[2]}` : null;
}

export async function listSnapshots(file = registryPath()) {
  try {
    const parsed = JSON.parse(await fs.readFile(file, 'utf8'));
    return Array.isArray(parsed) ? parsed : [];
  } catch (e) {
    if (e.code === 'ENOENT') return [];
    throw e;
  }
}

/** Append one record `{ snapshotId, repo, gtmSha, lockfileHash, anvilSha, builtAt, ... }`; newest last. */
export async function recordSnapshot(record, file = registryPath()) {
  const all = (await listSnapshots(file)).filter(r => r.snapshotId !== record.snapshotId);
  all.push(record);
  await fs.mkdir(path.dirname(file), { recursive: true });
  await fs.writeFile(file, JSON.stringify(all, null, 2) + '\n', { mode: 0o600 });
  return all;
}

/** Newest registered snapshot of `repo` whose lockfile hash is `lockfileHash`, or null. */
export function findSnapshot(records, repo, lockfileHash) {
  return records
    .filter(r => r.repo === repo && r.lockfileHash === lockfileHash)
    .sort((a, b) => String(b.builtAt).localeCompare(String(a.builtAt)))[0] ?? null;
}
