// Package-manager detection and the install/toolchain commands it drives (anvil#63).
//
// Pure and I/O-free so build-snapshot.mjs (and its tests) can feed it a ref's tree listing
// and parsed package.json without a checkout. The lane supports pnpm and npm; yarn repos are
// out of scope until something needs them.
const PNPM_LOCKFILE = 'pnpm-lock.yaml';
const NPM_LOCKFILE = 'package-lock.json';
const YARN_LOCKFILE = 'yarn.lock';
export const DEFAULT_PNPM_VERSION = '10.33.0';

/**
 * `{ files, packageJson }` -> `{ name, version, lockfile }`. `packageManager` (corepack's field)
 * wins and supplies the version; otherwise the lockfile on disk decides, with no version (the
 * caller picks a default for pnpm; npm ships with Node so there is nothing to pin). A repo that
 * carries both lockfiles, or neither, cannot be built reproducibly and is refused rather than
 * guessed at.
 */
export function detectPackageManager({ files, packageJson }) {
  const pmField = typeof packageJson?.packageManager === 'string' ? packageJson.packageManager : null;
  const fieldMatch = pmField ? /^(pnpm|npm)@([^\s+]+)/.exec(pmField) : null;
  if (fieldMatch) {
    const [, name, version] = fieldMatch;
    // The version is interpolated into the build sandbox's shell; a repo's package.json must not
    // be able to add commands to it.
    if (!/^\d+\.\d+\.\d+(?:-[0-9A-Za-z.]+)?$/.test(version)) throw new Error(`packageManager version is not a plain semver: ${version}`);
    return { name, version, lockfile: name === 'pnpm' ? PNPM_LOCKFILE : NPM_LOCKFILE };
  }
  const list = Array.isArray(files) ? files : [];
  if (list.includes(YARN_LOCKFILE)) throw new Error('yarn is not supported by the lane');
  const hasPnpm = list.includes(PNPM_LOCKFILE), hasNpm = list.includes(NPM_LOCKFILE);
  if (hasPnpm && hasNpm) throw new Error(`both ${PNPM_LOCKFILE} and ${NPM_LOCKFILE} are present; ambiguous package manager`);
  if (!hasPnpm && !hasNpm) throw new Error(`no supported lockfile found (${PNPM_LOCKFILE} or ${NPM_LOCKFILE})`);
  return hasPnpm ? { name: 'pnpm', version: null, lockfile: PNPM_LOCKFILE } : { name: 'npm', version: null, lockfile: NPM_LOCKFILE };
}

/** The frozen, offline-capable install the snapshot warms its store with. */
export function installCommand(manager) {
  return manager.name === 'pnpm' ? 'pnpm install --frozen-lockfile' : 'npm ci --no-audit --no-fund';
}

/**
 * What the seal phase runs in a node_modules-free copy to prove the snapshot serves the lockfile
 * with no network. For npm it is the command anvil runs in a fresh worktree (plain npm install),
 * under the offline setting from offlineConfigCommand, so the proof and the dispatch take the
 * same path.
 */
export function offlineInstallCommand(manager) {
  return manager.name === 'pnpm' ? 'pnpm install --frozen-lockfile --offline' : 'npm install --no-audit --no-fund';
}

/**
 * Persistent offline setting for the snapshot, or null. anvil installs an npm worktree with plain
 * npm install, which retries a blocked registry before it reads the cache; pnpm already gets
 * --prefer-offline from anvil.
 */
export function offlineConfigCommand(manager) {
  return manager.name === 'npm' ? 'npm config set offline true --location=user' : null;
}

/** Shell lines that put the detected manager on PATH inside the sandbox. */
export function toolchainScript(manager) {
  if (manager.name === 'pnpm') {
    const version = manager.version ?? DEFAULT_PNPM_VERSION;
    return `corepack enable >/dev/null 2>&1 || sudo -n corepack enable\ncorepack prepare pnpm@${version} --activate\nnode -v; pnpm -v`;
  }
  // npm ships with Node; there is no toolchain step to run.
  return 'node -v && npm -v';
}
