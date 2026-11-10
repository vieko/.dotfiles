#!/usr/bin/env node
// Build a base snapshot for the sandbox golem lane (anvil#59, per-repo anvil#63).
//
// The snapshot holds what a dispatch cannot fetch once egress drops to the AI gateway:
// build-essential, the target repo's package manager, a warm store for one exact lockfile, and
// anvil at a pinned revision. It holds no repository checkout, no credential, and no run record.
// The controller clones the fork SHA itself and refuses a snapshot whose lockfile hash differs
// from the fork's.
//
// The repository tree comes from a local `git archive` upload, not a clone, so the build needs
// no GitHub credential. The build sandbox allows all egress because nothing secret is inside it;
// the dispatch firewall is a separate policy in anvil-sandbox.mjs.
//
// Each build is spend: run it only on explicit approval, and only when the target repo's
// lockfile or the anvil pin moved.
//
// usage: node build-snapshot.mjs --repo <path> [--ref origin/main]
//                                 [--anvil-ref origin/main] [--vcpus 4]
import { execFile } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseArgs, promisify } from 'node:util';
import { Sandbox } from '@vercel/sandbox';
import { getAuth } from '@vercel/sandbox/dist/auth/index.js';
import { recordSnapshot, registryPath, repoSlug } from './snapshot-registry.mjs';
import { detectPackageManager, installCommand, offlineConfigCommand, offlineInstallCommand, toolchainScript } from './snapshot-toolchain.mjs';

const execFileAsync = promisify(execFile);
const here = path.dirname(fileURLToPath(import.meta.url));
const { values: opts } = parseArgs({ options: {
  repo: { type: 'string' },
  ref: { type: 'string', default: 'origin/main' },
  'anvil-ref': { type: 'string', default: 'origin/main' },
  vcpus: { type: 'string', default: '4' },
  'keep-sandbox': { type: 'boolean', default: false },
} });

const CHUNK = 16 * 1024 * 1024;
const HOME = '/vercel';
const say = m => console.error(`[${new Date().toISOString()}] ${m}`);

async function git(repo, args) { return (await execFileAsync('git', ['-C', repo, ...args], { maxBuffer: 2 ** 30 })).stdout.trim(); }
async function gitShow(repo, ref, file) { return (await execFileAsync('git', ['-C', repo, 'show', `${ref}:${file}`], { maxBuffer: 2 ** 28 })).stdout; }

async function main() {
  if (!opts.repo) throw new Error('--repo is required');
  const link = JSON.parse(await fs.readFile(path.join(here, '.vercel/project.json'), 'utf8'));
  const auth = getAuth();
  if (!auth?.token) throw new Error('no Vercel CLI auth; run vercel login');
  const anvilRepo = path.join(os.homedir(), 'dev/anvil');
  await git(opts.repo, ['fetch', '-q', 'origin', 'main']);
  await git(anvilRepo, ['fetch', '-q', 'origin', 'main']);
  const repoSha = await git(opts.repo, ['rev-parse', opts.ref]);
  const anvilSha = await git(anvilRepo, ['rev-parse', opts['anvil-ref']]);
  const repo = repoSlug(await git(opts.repo, ['remote', 'get-url', 'origin']));
  if (!repo) throw new Error("--repo's origin remote is not a GitHub URL; cannot derive a slug (anvil#63)");

  // The manager is detected from the ref's tree, not the working tree: the snapshot is built for
  // the exact commit it hashes the lockfile from, and a dirty or differently-checked-out worktree
  // must not change what gets built (anvil#63).
  const files = (await git(opts.repo, ['ls-tree', '--name-only', repoSha])).split('\n').filter(Boolean);
  let packageJson = null;
  if (files.includes('package.json')) {
    try { packageJson = JSON.parse(await gitShow(opts.repo, repoSha, 'package.json')); } catch { packageJson = null; }
  }
  const manager = detectPackageManager({ files, packageJson });
  const lockfile = await gitShow(opts.repo, repoSha, manager.lockfile);
  const lockfileHash = createHash('sha256').update(lockfile).digest('hex');
  const archive = (await execFileAsync('bash', ['-c', `git -C ${JSON.stringify(opts.repo)} archive --format=tar ${repoSha} | gzip -1`], { encoding: 'buffer', maxBuffer: 2 ** 31 })).stdout;
  say(`${repo} ${repoSha.slice(0, 9)} ${manager.name} lockfile ${lockfileHash.slice(0, 12)} archive ${(archive.length / 1e6).toFixed(0)} MB; anvil ${anvilSha.slice(0, 9)}`);

  const sandbox = await Sandbox.create({
    token: auth.token, teamId: link.orgId, projectId: link.projectId,
    image: 'vercel/sandbox/universal', resources: { vcpus: Number(opts.vcpus) },
    timeout: 40 * 60_000, persistent: false,
    env: { CI: '1', GIT_TERMINAL_PROMPT: '0' },
    tags: { purpose: 'golem-snapshot-build', repo: repo.replace('/', '-'), ref: repoSha.slice(0, 9), anvil: anvilSha.slice(0, 9) },
  });
  say(`sandbox ${sandbox.name}`);
  const sh = async (script, { allowFail = false } = {}) => {
    const r = await sandbox.runCommand({ cmd: 'bash', args: ['-lc', script] });
    const out = String(await r.output('both'));
    if (r.exitCode !== 0 && !allowFail) throw new Error(`exit ${r.exitCode}: ${script.slice(0, 80)}\n${out.slice(-3000)}`);
    return out;
  };
  const phase = async (name, fn) => { const t = Date.now(); say(`>> ${name}`); const r = await fn(); say(`<< ${name} ${((Date.now() - t) / 1000).toFixed(1)}s`); return r; };
  let snapshotId, packageManagerVersion, packageManagerRecorded;
  try {
    const home = (await sh('printf %s "$HOME"')).trim();
    if (home !== HOME) throw new Error(`sandbox HOME is ${home}, expected ${HOME}; update the controller`);
    await phase('toolchain', () => sh(`set -eo pipefail
      # shellcheck: actionlint runs it on workflow run blocks only when the binary is on PATH;
      # without it a broken line continuation passed the GTMENG-4177 replay gate (anvil#59).
      sudo -n apt-get -qq update >/dev/null && sudo -n apt-get -qq install -y build-essential shellcheck >/dev/null && shellcheck --version | head -2
      curl -fsSL https://raw.githubusercontent.com/rhysd/actionlint/main/scripts/download-actionlint.bash | sudo -n bash -s -- latest /usr/local/bin >/dev/null && actionlint --version
      ${toolchainScript(manager)}
      make --version | head -1`));
    packageManagerVersion = (await sh(`${manager.name} -v`)).trim().split('\n').pop();
    await phase('upload-seed', async () => {
      await sh(`rm -rf ${HOME}/seed-parts && mkdir -p ${HOME}/seed-parts`);
      for (let i = 0, n = 0; i < archive.length; i += CHUNK, n++) {
        await sandbox.writeFiles([{ path: `${HOME}/seed-parts/${String(n).padStart(4, '0')}`, content: archive.subarray(i, i + CHUNK) }]);
      }
      const remoteHash = (await sh(`cat ${HOME}/seed-parts/* | sha256sum`)).split(/\s/)[0];
      const localHash = createHash('sha256').update(archive).digest('hex');
      if (remoteHash !== localHash) throw new Error('seed archive hash mismatch after upload');
      await sh(`set -e; mkdir -p ${HOME}/seed && cat ${HOME}/seed-parts/* | tar -xz -C ${HOME}/seed && rm -rf ${HOME}/seed-parts && test -f ${HOME}/seed/${manager.lockfile}`);
    });
    await phase('warm-store', () => sh(manager.name === 'pnpm'
      ? `set -eo pipefail; cd ${HOME}/seed && ${installCommand(manager)} 2>&1 | tail -3 && pnpm store path && du -sh "$(pnpm store path)" | cut -f1`
      : `set -eo pipefail; cd ${HOME}/seed && ${installCommand(manager)} 2>&1 | tail -3 && du -sh "$HOME/.npm" | cut -f1`));
    await phase('anvil', () => sh(`set -eo pipefail
      cd ${HOME} && git clone --quiet https://github.com/vieko/anvil.git && cd anvil && git checkout --quiet ${anvilSha}
      npm_config_min_release_age=0 npm ci --no-audit --no-fund 2>&1 | tail -1
      printf '#!/usr/bin/env bash\\nexec node --conditions=anvil-source ${HOME}/anvil/packages/cli/src/bin.ts "$@"\\n' | sudo -n tee /usr/local/bin/anvil >/dev/null
      sudo -n chmod 755 /usr/local/bin/anvil
      cd / && anvil --help | grep -q -- --gate-timeout`));
    const packageManager = `${manager.name}@${packageManagerVersion}`;
    const buildJson = JSON.stringify({ repo, repoSha, anvilSha, packageManager, lockfile: manager.lockfile, builtAt: new Date().toISOString() });
    // ~/.cache/node is corepack's pnpm cache; without it the first pnpm call downloads pnpm,
    // which gateway-only egress blocks. npm ships with Node, so there is nothing to re-assert.
    const offlineManagerAssertion = manager.name === 'pnpm' ? 'COREPACK_ENABLE_NETWORK=0 pnpm -v >/dev/null' : 'true';
    await phase('seal', () => sh(`set -eo pipefail
      # Proof runs against a fresh copy of the seed so it exercises the warmed store/cache, not
      # the node_modules the warm-store phase already left on disk (anvil#63).
      rm -rf ${HOME}/seal-check && mkdir -p ${HOME}/seal-check
      tar -C ${HOME}/seed --exclude=node_modules -cf - . | tar -C ${HOME}/seal-check -xf -
      ${offlineConfigCommand(manager) ?? 'true'}
      cd ${HOME}/seal-check && ${offlineInstallCommand(manager)} 2>&1 | tail -3
      cd / && rm -rf ${HOME}/seal-check ${HOME}/seed ${HOME}/.npm/_logs ${HOME}/.anvil
      ${offlineManagerAssertion}
      sudo -n mkdir -p /opt/anvil-snapshot
      printf '%s  %s\\n' ${lockfileHash} ${manager.lockfile} | sudo -n tee /opt/anvil-snapshot/lockfile.sha256 >/dev/null
      printf '%s\\n' '${buildJson}' | sudo -n tee /opt/anvil-snapshot/build.json >/dev/null
      (grep -rIl -E 'gho_|ghp_|github_pat_|vcp_|VERCEL_TOKEN' ${HOME} /opt/anvil-snapshot --exclude-dir=node_modules --exclude-dir=.git 2>/dev/null || true) | head -3
      cat /opt/anvil-snapshot/lockfile.sha256; df -h / | tail -1`));
    const snapshot = await phase('snapshot', () => sandbox.snapshot());
    snapshotId = snapshot.snapshotId;
    packageManagerRecorded = packageManager;
  } finally {
    if (!opts['keep-sandbox']) await sandbox.stop().catch(e => say(`stop failed: ${e.message}`));
  }
  const record = { snapshotId, repo, repoSha, lockfile: manager.lockfile, lockfileHash, packageManager: packageManagerRecorded, anvilSha, vcpus: Number(opts.vcpus), builtAt: new Date().toISOString() };
  await recordSnapshot(record);
  say(`recorded in ${registryPath()}`);
  console.log(JSON.stringify({ ...record, teamId: link.orgId, projectId: link.projectId }, null, 2));
}

main().catch(e => { say(`[ERROR] ${e.message}`); process.exitCode = 1; });
