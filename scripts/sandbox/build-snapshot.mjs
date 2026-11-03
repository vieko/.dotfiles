#!/usr/bin/env node
// Build the base snapshot for the sandbox golem lane (anvil#59).
//
// The snapshot holds what a dispatch cannot fetch once egress drops to the
// AI gateway: build-essential, pnpm, a warm pnpm store for one exact gtm
// lockfile, and anvil at a pinned revision. It holds no repository checkout,
// no credential, and no run record. The controller clones the fork SHA itself
// and refuses a snapshot whose lockfile hash differs from the fork's.
//
// The repository tree comes from a local `git archive` upload, not a clone, so
// the build needs no GitHub credential. The build sandbox allows all egress
// because nothing secret is inside it; the dispatch firewall is a separate
// policy in anvil-sandbox.mjs.
//
// Each build is spend: run it only on explicit approval, and only when the
// gtm lockfile or the anvil pin moved.
//
// usage: node build-snapshot.mjs [--repo ~/dev/gtm] [--ref origin/main]
//                                [--anvil-ref origin/main] [--vcpus 4]
import { execFile } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseArgs, promisify } from 'node:util';
import { Sandbox } from '@vercel/sandbox';
import { getAuth } from '@vercel/sandbox/dist/auth/index.js';

const execFileAsync = promisify(execFile);
const here = path.dirname(fileURLToPath(import.meta.url));
const { values: opts } = parseArgs({ options: {
  repo: { type: 'string', default: path.join(os.homedir(), 'dev/gtm') },
  ref: { type: 'string', default: 'origin/main' },
  'anvil-ref': { type: 'string', default: 'origin/main' },
  vcpus: { type: 'string', default: '4' },
  'keep-sandbox': { type: 'boolean', default: false },
} });

const PNPM_VERSION = '10.33.0';
const CHUNK = 16 * 1024 * 1024;
const HOME = '/vercel';
const say = m => console.error(`[${new Date().toISOString()}] ${m}`);

async function git(repo, args) { return (await execFileAsync('git', ['-C', repo, ...args], { maxBuffer: 2 ** 30 })).stdout.trim(); }

async function main() {
  const link = JSON.parse(await fs.readFile(path.join(here, '.vercel/project.json'), 'utf8'));
  const auth = getAuth();
  if (!auth?.token) throw new Error('no Vercel CLI auth; run vercel login');
  const anvilRepo = path.join(os.homedir(), 'dev/anvil');
  await git(opts.repo, ['fetch', '-q', 'origin', 'main']);
  await git(anvilRepo, ['fetch', '-q', 'origin', 'main']);
  const gtmSha = await git(opts.repo, ['rev-parse', opts.ref]);
  const anvilSha = await git(anvilRepo, ['rev-parse', opts['anvil-ref']]);
  const lockfile = (await execFileAsync('git', ['-C', opts.repo, 'show', `${gtmSha}:pnpm-lock.yaml`], { maxBuffer: 2 ** 28 })).stdout;
  const lockfileHash = createHash('sha256').update(lockfile).digest('hex');
  const archive = (await execFileAsync('bash', ['-c', `git -C ${JSON.stringify(opts.repo)} archive --format=tar ${gtmSha} | gzip -1`], { encoding: 'buffer', maxBuffer: 2 ** 31 })).stdout;
  say(`gtm ${gtmSha.slice(0, 9)} lockfile ${lockfileHash.slice(0, 12)} archive ${(archive.length / 1e6).toFixed(0)} MB; anvil ${anvilSha.slice(0, 9)}`);

  const sandbox = await Sandbox.create({
    token: auth.token, teamId: link.orgId, projectId: link.projectId,
    image: 'vercel/sandbox/universal', resources: { vcpus: Number(opts.vcpus) },
    timeout: 40 * 60_000, persistent: false,
    env: { CI: '1', GIT_TERMINAL_PROMPT: '0' },
    tags: { purpose: 'golem-snapshot-build', gtm: gtmSha.slice(0, 9), anvil: anvilSha.slice(0, 9) },
  });
  say(`sandbox ${sandbox.name}`);
  const sh = async (script, { allowFail = false } = {}) => {
    const r = await sandbox.runCommand({ cmd: 'bash', args: ['-lc', script] });
    const out = String(await r.output('both'));
    if (r.exitCode !== 0 && !allowFail) throw new Error(`exit ${r.exitCode}: ${script.slice(0, 80)}\n${out.slice(-3000)}`);
    return out;
  };
  const phase = async (name, fn) => { const t = Date.now(); say(`>> ${name}`); const r = await fn(); say(`<< ${name} ${((Date.now() - t) / 1000).toFixed(1)}s`); return r; };
  let snapshotId;
  try {
    const home = (await sh('printf %s "$HOME"')).trim();
    if (home !== HOME) throw new Error(`sandbox HOME is ${home}, expected ${HOME}; update the controller`);
    await phase('toolchain', () => sh(`set -eo pipefail
      sudo -n apt-get -qq update >/dev/null && sudo -n apt-get -qq install -y build-essential >/dev/null
      corepack enable >/dev/null 2>&1 || sudo -n corepack enable
      corepack prepare pnpm@${PNPM_VERSION} --activate
      node -v; pnpm -v; make --version | head -1`));
    await phase('upload-seed', async () => {
      await sh(`rm -rf ${HOME}/seed-parts && mkdir -p ${HOME}/seed-parts`);
      for (let i = 0, n = 0; i < archive.length; i += CHUNK, n++) {
        await sandbox.writeFiles([{ path: `${HOME}/seed-parts/${String(n).padStart(4, '0')}`, content: archive.subarray(i, i + CHUNK) }]);
      }
      const remoteHash = (await sh(`cat ${HOME}/seed-parts/* | sha256sum`)).split(/\s/)[0];
      const localHash = createHash('sha256').update(archive).digest('hex');
      if (remoteHash !== localHash) throw new Error('seed archive hash mismatch after upload');
      await sh(`set -e; mkdir -p ${HOME}/seed && cat ${HOME}/seed-parts/* | tar -xz -C ${HOME}/seed && rm -rf ${HOME}/seed-parts && test -f ${HOME}/seed/pnpm-lock.yaml`);
    });
    await phase('warm-store', () => sh(`set -eo pipefail; cd ${HOME}/seed && pnpm install --frozen-lockfile 2>&1 | tail -3 && pnpm store path && du -sh "$(pnpm store path)" | cut -f1`));
    await phase('anvil', () => sh(`set -eo pipefail
      cd ${HOME} && git clone --quiet https://github.com/vieko/anvil.git && cd anvil && git checkout --quiet ${anvilSha}
      npm_config_min_release_age=0 npm ci --no-audit --no-fund 2>&1 | tail -1
      printf '#!/usr/bin/env bash\\nexec node --conditions=anvil-source ${HOME}/anvil/packages/cli/src/bin.ts "$@"\\n' | sudo -n tee /usr/local/bin/anvil >/dev/null
      sudo -n chmod 755 /usr/local/bin/anvil
      cd / && anvil --help | grep -q -- --gate-timeout`));
    await phase('seal', () => sh(`set -eo pipefail
      rm -rf ${HOME}/seed ${HOME}/.npm/_logs ${HOME}/.cache/node ${HOME}/.anvil
      sudo -n mkdir -p /opt/anvil-snapshot
      printf '%s  pnpm-lock.yaml\\n' ${lockfileHash} | sudo -n tee /opt/anvil-snapshot/lockfile.sha256 >/dev/null
      printf '%s\\n' '${JSON.stringify({ gtmSha, anvilSha, pnpm: PNPM_VERSION, builtAt: new Date().toISOString() })}' | sudo -n tee /opt/anvil-snapshot/build.json >/dev/null
      (grep -rIl -E 'gho_|ghp_|github_pat_|vcp_|VERCEL_TOKEN' ${HOME} /opt/anvil-snapshot --exclude-dir=node_modules --exclude-dir=.git 2>/dev/null || true) | head -3
      cat /opt/anvil-snapshot/lockfile.sha256; df -h / | tail -1`));
    const snapshot = await phase('snapshot', () => sandbox.snapshot());
    snapshotId = snapshot.snapshotId;
  } finally {
    if (!opts['keep-sandbox']) await sandbox.stop().catch(e => say(`stop failed: ${e.message}`));
  }
  console.log(JSON.stringify({ snapshotId, teamId: link.orgId, projectId: link.projectId, gtmSha, anvilSha, lockfileHash }, null, 2));
}

main().catch(e => { say(`[ERROR] ${e.message}`); process.exitCode = 1; });
