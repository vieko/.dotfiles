#!/usr/bin/env node
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import os from 'node:os';
import fsNative from 'node:fs/promises';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { getVercelOidcToken } from '@vercel/oidc';
import { findSnapshot, listSnapshots, repoSlug } from './snapshot-registry.mjs';

const execFileAsync = promisify(execFile);
const KEYS = ['repoUrl','forkSha','specPath','gate','scopes','contracts','model','gateTimeout','snapshotId','teamId','projectId','ghStsPolicy','vcpus','timeoutMs','localRepo','dispatchId','summonerAddress','rebuildSnapshot'];
// snapshotId and ghStsPolicy are optional (anvil#63): a public repo needs no clone credential,
// and a repo with no approved snapshot yet is selected from the registry instead of pinned.
const OPTIONAL_KEYS = ['gateTimeout', 'rebuildSnapshot', 'snapshotId', 'ghStsPolicy'];
const SECRET_ENV = ['VERCEL_TOKEN','AI_GATEWAY_API_KEY'];
const GH_STS_URL = 'https://gh-sts.vercel-infra.com/token';
const GH_STS_SETUP_BUDGET_MS = 10 * 60_000;
// The universal image's user is `vercel` with HOME=/vercel (spike log, anvil#59), not /home/vercel.
const REMOTE_HOME = '/vercel';
/** anvil's per-repo state bucket (packages/cli/src/state-paths.ts): the absolute path, separators to dashes, wrapped in `--`. */
export const anvilBucket = repoRoot => `--${repoRoot.replace(/^[/\\]/, '').replace(/[/\\:]/g, '-')}--`;
const SHA_RE = /^[0-9a-f]{40}$/i;
const COLLECTION_RESERVE_MS = 5 * 60_000;
const q = (s) => `'${String(s).replaceAll("'", "'\\''")}'`;
const safeName = (s) => /^[A-Za-z0-9][A-Za-z0-9._-]{0,80}$/.test(s) && !s.includes('..');

export function validateRequest(r, requestPath) {
  if (!r || typeof r !== 'object' || Array.isArray(r)) throw new Error('request must be a JSON object');
  for (const k of Object.keys(r)) if (!KEYS.includes(k)) throw new Error(`unknown request key: ${k}`);
  for (const k of KEYS) if (!OPTIONAL_KEYS.includes(k) && (r[k] === undefined || r[k] === null || r[k] === '')) throw new Error(`missing required field: ${k}`);
  const repoParts = typeof r.repoUrl === 'string' ? r.repoUrl.split('/').slice(3) : [];
  if (!/^https:\/\/github\.com\/[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+(?:\.git)?$/.test(r.repoUrl) || repoParts.length !== 2 || repoParts.some(x => x === '.' || x === '..')) throw new Error('repoUrl must be one HTTPS GitHub repository');
  if (!SHA_RE.test(r.forkSha)) throw new Error('forkSha must be a 40-character SHA');
  if (!Array.isArray(r.gate) || !r.gate.length || r.gate.some(x => typeof x !== 'string' || !x.trim() || /(^|\s)--link(?:\s|$)/.test(x))) throw new Error('gate must be a non-empty array of commands and may not use --link');
  for (const key of ['scopes','contracts']) if (!Array.isArray(r[key]) || r[key].some(x => typeof x !== 'string' || !x.trim() || x.startsWith('/') || x.split(/[\\/]/).includes('..'))) throw new Error(`${key} must contain safe relative values`);
  const contractNames = r.contracts.map(x => path.basename(x));
  if (new Set(contractNames).size !== contractNames.length) throw new Error('contract inputs must have unique basenames');
  if ([...r.gate,...r.scopes,...r.contracts,r.model].some(x => /(^|[\s=])--link(?:[\s]|$)/.test(x) || /(?:~\/|\/(?:Users|home|tmp|var|private|workspace|mnt|root|opt)\/)/.test(x))) throw new Error('inputs may not use --link or host paths');
  if (r.model.startsWith('-') || r.scopes.some(x => x.startsWith('-'))) throw new Error('model and scope values may not be option-like');
  if (typeof r.localRepo !== 'string' || !path.isAbsolute(r.localRepo)) throw new Error('localRepo must be an absolute host path');
  for (const k of ['model','teamId','projectId','dispatchId','summonerAddress']) if (typeof r[k] !== 'string' || !r[k].trim()) throw new Error(`${k} must be a non-empty string`);
  for (const k of ['snapshotId','ghStsPolicy']) if (r[k] !== undefined && (typeof r[k] !== 'string' || !r[k].trim())) throw new Error(`${k} must be a non-empty string`);
  if (!safeName(r.dispatchId)) throw new Error('dispatchId must be a safe identifier');
  for (const k of ['snapshotId','ghStsPolicy']) if (r[k] !== undefined && !safeName(r[k])) throw new Error(`${k} must be a safe identifier`);
  if (!Number.isInteger(r.vcpus) || r.vcpus < 1 || r.vcpus > 32 || !Number.isInteger(r.timeoutMs) || r.timeoutMs <= COLLECTION_RESERVE_MS + 30_000) throw new Error('vcpus and timeoutMs must leave a five-minute collection window');
  if (r.rebuildSnapshot !== undefined && typeof r.rebuildSnapshot !== 'boolean') throw new Error('rebuildSnapshot must be a boolean');
  if (r.gateTimeout !== undefined && (typeof r.gateTimeout !== 'string' || !/^\d+[smh]$/.test(r.gateTimeout))) throw new Error('gateTimeout must be a duration');
  const reqDir = path.resolve(path.dirname(requestPath));
  const spec = path.resolve(reqDir, r.specPath);
  if (!inside(reqDir, spec) || path.isAbsolute(r.specPath) || r.specPath.split(/[\\/]/).includes('..')) throw new Error('specPath must stay within the request directory');
  return { ...r, gateTimeout: r.gateTimeout ?? '600s', requestDir: reqDir, absoluteSpecPath: spec };
}
function inside(base, target) { return target === base || target.startsWith(base + path.sep); }
function containsSecret(text,secrets) { return secrets.some(secret=>secret && (text.includes(secret)||text.includes(Buffer.from(secret).toString('base64')))); }

const sanitize = (x, secrets) => {
  let s = typeof x === 'string' ? x : JSON.stringify(x);
  for (const secret of secrets) if (secret) {
    s = s.split(secret).join('[REDACTED]');
    s = s.split(Buffer.from(secret).toString('base64')).join('[REDACTED]');
  }
  return s;
};

/** All orchestration is injectable; only main() binds host and SDK effects. */
export async function runController(requestPath, effects) {
  const { sdk, fs, git, exec, clock, log, credentials, snapshots } = effects;
  let req, secrets = [], sandbox, exitCode = 4, dispatched = false, collected = false, worktreesBefore = [];
  const state = { sandboxId: null, stopStatus: 'not-started', retrievalStatus: 'not-started', importStatus: 'not-started', branch: null, worktree: null, remoteWorktree: null, artifactDir: null, verdict: 'inconclusive', stopError: null };
  const pendingLogs = [];
  const say = (message) => {
    const safe = sanitize(message, secrets);
    log(safe);
    if (state.artifactDir) pendingLogs.push(fs.appendFile(path.join(state.artifactDir, 'controller.log'), `${safe}\n`).catch(() => {}));
  };
  try {
    const raw = await fs.readFile(requestPath, 'utf8');
    req = validateRequest(JSON.parse(raw), requestPath);
    if (!clock.homeDir) throw new Error('clock.homeDir is required');
    const reqStat = await fs.lstat(requestPath);
    if (reqStat.isSymbolicLink() || !reqStat.isFile()) throw new Error('request path must be a regular non-symlink file');
    const env = clock.env ?? {};
    for(const [field,key] of [['teamId','VERCEL_TEAM_ID'],['projectId','VERCEL_PROJECT_ID']]) if(!env[key]||req[field]!==env[key]) throw new Error(`${field} must match ${key}`);
    // snapshotId is optional (anvil#63): when present it still has to be the one this controller is
    // approved to use; when absent, the registry pre-check below picks the snapshot instead.
    if (req.snapshotId !== undefined && (!env.ANVIL_SANDBOX_SNAPSHOT_ID || req.snapshotId !== env.ANVIL_SANDBOX_SNAPSHOT_ID)) throw new Error('snapshotId must match ANVIL_SANDBOX_SNAPSHOT_ID');
    secrets = SECRET_ENV.map(k => env[k]).filter(Boolean);
    if (secrets.length !== 2) throw new Error('VERCEL_TOKEN and AI_GATEWAY_API_KEY are required');
    secrets.push(`Bearer ${env.AI_GATEWAY_API_KEY}`);
    if(containsSecret(raw,secrets)) throw new Error('request JSON must not contain credential values');
    await assertRegularContained(fs, req.requestDir, req.absoluteSpecPath, 'spec');
    const specContent=await fs.readFile(req.absoluteSpecPath,'utf8');
    if(containsSecret(specContent,secrets)) throw new Error('spec input contains a credential value');
    const contractContents=[];
    for (const c of req.contracts) {
      const p = path.resolve(req.requestDir, c);
      if (!inside(req.requestDir, p) || c.split(/[\\/]/).includes('..')) throw new Error('contract path escapes request directory');
      await assertRegularContained(fs, req.requestDir, p, 'contract');
      const content=await fs.readFile(p,'utf8'); if(containsSecret(content,secrets)) throw new Error(`contract input contains a credential value: ${c}`);
      contractContents.push({name:path.basename(c),content});
    }
    const repoStat = await fs.lstat(path.resolve(req.localRepo));
    if (repoStat.isSymbolicLink() || !repoStat.isDirectory()) throw new Error('localRepo must be an existing non-symlink directory');
    state.branch = `golem/${req.dispatchId}`;
    state.worktree = path.join(path.resolve(req.localRepo), '.anvil-worktrees', req.dispatchId);
    const artifactRoot = path.join(clock.homeDir, 'scratch', 'logs');
    state.artifactDir = path.join(artifactRoot, `golem-${path.basename(req.localRepo)}-${req.dispatchId}`);
    await fs.mkdir(artifactRoot, { recursive: true });
    await fs.mkdir(state.artifactDir, { recursive: false });
    await fs.mkdir(path.dirname(state.worktree), { recursive: true });
    await git.assertClean(req.localRepo);
    await git.refuseCollision(req.localRepo, state.branch, state.worktree);
    await git.worktreeAdd(req.localRepo, state.worktree, req.forkSha, state.branch);
    await fs.writeFile(path.join(state.artifactDir, 'request.json'), JSON.stringify({ ...req, absoluteSpecPath: undefined, requestDir: undefined }, null, 2));
    const manifest = { dispatchId: req.dispatchId, snapshotId: req.snapshotId, forkSha: req.forkSha, repoUrl: req.repoUrl, branch: state.branch, worktree: state.worktree, remoteWorktree: null, createdAt: clock.now().toISOString(), sandboxId: null, lockfileHash: await git.lockfileHash(state.worktree), status: 'allocated' };
    await fs.writeFile(path.join(state.artifactDir, 'manifest.json'), JSON.stringify(manifest, null, 2));
    // ghStsPolicy is optional (anvil#63): a public repo clones anonymously over https, so there is
    // no gh-sts request, no minted GitHub token, and no Authorization transform on the github.com
    // rules below. Absent a policy, the anonymous git ls-remote probe later is the only proof the
    // repo is reachable.
    let gh, ghBasic;
    if (req.ghStsPolicy) {
      const oidc = await credentials.getOidcToken();
      if (typeof oidc !== 'string' || !oidc) throw new Error('Vercel OIDC did not return a token');
      secrets.push(oidc, `Bearer ${oidc}`);
      const stsResponse = await credentials.fetch(GH_STS_URL, {
        method: 'POST',
        headers: { Authorization: `Bearer ${oidc}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ owner: new URL(req.repoUrl).pathname.split('/')[1], repo: new URL(req.repoUrl).pathname.split('/')[2].replace(/\.git$/, ''), permissions: { contents: 'read' }, policy: req.ghStsPolicy }),
      });
      if (!stsResponse.ok) {
        const responseBody = await stsResponse.text();
        const denial = responseBody.includes('POLICY_DENIED') ? `; POLICY_DENIED: ${responseBody}` : '';
        // gh-sts bans a source IP after repeated policy denials with no decay; never retry this request.
        throw new Error(`gh-sts policy ${req.ghStsPolicy} failed (${stsResponse.status})${denial}`);
      }
      const stsBody = await stsResponse.json();
      if (typeof stsBody?.token !== 'string' || !stsBody.token) throw new Error(`gh-sts policy ${req.ghStsPolicy} response did not include a token`);
      const expiresAt = Date.parse(stsBody.expires_at);
      if (!Number.isFinite(expiresAt)) throw new Error(`gh-sts policy ${req.ghStsPolicy} response had invalid expires_at`);
      if (expiresAt - clock.now().getTime() < GH_STS_SETUP_BUDGET_MS) throw new Error(`gh-sts policy ${req.ghStsPolicy} token expires before the 10-minute setup budget`);
      gh = stsBody.token;
      ghBasic = Buffer.from(`x-access-token:${gh}`).toString('base64');
      secrets.push(gh, ghBasic, `Basic ${ghBasic}`);
    }
    const gateway = env.AI_GATEWAY_API_KEY;
    const gatewayRule = { transform: [{ headers: { Authorization: `Bearer ${gateway}` } }] };
    // The match scopes the credential, not access: an allowed domain admits every request, and a
    // rule must carry a transform, forwardURL, or response. An anonymous clone has no header to
    // add, so it gets the plain allow (anvil#63).
    const githubRules = gh ? [
      { match: { path: { exact: repoPath(req.repoUrl) + '/info/refs' }, method: ['GET'], queryString: [{ key: { exact: 'service' }, value: { exact: 'git-upload-pack' } }] }, transform: [{ headers: { Authorization: `Basic ${ghBasic}` } }] },
      { match: { path: { exact: repoPath(req.repoUrl) + '/git-upload-pack' }, method: ['POST'] }, transform: [{ headers: { Authorization: `Basic ${ghBasic}` } }] },
    ] : [];
    const setupPolicy = { allow: { 'github.com': githubRules, 'ai-gateway.vercel.sh': [gatewayRule] } };
    const agentPolicy = { allow: { 'ai-gateway.vercel.sh': [gatewayRule] } };
    // Registry pre-check (anvil#59, per-repo anvil#63): the snapshot used must have been built from
    // the fork's lockfile for this repo. With a pinned snapshotId, an unregistered snapshot skips
    // this and relies on the in-sandbox hash check below; with no snapshotId, this pre-check is the
    // only selection there is. Reusing another registered snapshot costs nothing; a rebuild is
    // spend, so it needs rebuildSnapshot: true in the request.
    let snapshotId = req.snapshotId;
    const records = snapshots ? await snapshots.list() : [];
    const slug = repoSlug(req.repoUrl);
    const approved = snapshotId !== undefined ? records.find(r => r.snapshotId === snapshotId) : undefined;
    const needsSelection = snapshotId === undefined || (approved && approved.lockfileHash !== manifest.lockfileHash);
    if (needsSelection) {
      const match = findSnapshot(records, slug, manifest.lockfileHash);
      const mismatchLabel = snapshotId !== undefined
        ? `snapshot lockfile mismatch (snapshot ${approved.lockfileHash.slice(0, 12)}, fork ${manifest.lockfileHash.slice(0, 12)})`
        : `snapshot lockfile mismatch (no registered snapshot for ${slug} with lockfile ${manifest.lockfileHash.slice(0, 12)})`;
      if (match) {
        say(snapshotId !== undefined
          ? `${mismatchLabel}; using ${match.snapshotId} (built ${match.builtAt})`
          : `using registered snapshot ${match.snapshotId} for ${slug} (lockfile ${manifest.lockfileHash.slice(0, 12)}, built ${match.builtAt})`);
        snapshotId = match.snapshotId;
      } else if (req.rebuildSnapshot) {
        say(`${mismatchLabel}; rebuilding at ${req.forkSha.slice(0, 9)}`);
        const built = await snapshots.build({ repo: req.localRepo, ref: req.forkSha });
        if (!built?.snapshotId || built.lockfileHash !== manifest.lockfileHash) throw new Error('snapshot rebuild did not produce a matching snapshot');
        snapshotId = built.snapshotId;
        say(req.snapshotId !== undefined
          ? `snapshot ${snapshotId} built; update ANVIL_SANDBOX_SNAPSHOT_ID to approve it for later dispatches`
          : `snapshot ${snapshotId} built and registered for ${slug}`);
      } else throw new Error(`${mismatchLabel}; set rebuildSnapshot: true or run build-snapshot.mjs --repo ${req.localRepo} --ref ${req.forkSha}`);
      manifest.snapshotId = snapshotId;
      await fs.writeFile(path.join(state.artifactDir, 'manifest.json'), JSON.stringify(manifest, null, 2));
    }
    state.snapshotId = snapshotId;
    sandbox = await sdk.create({ token: env.VERCEL_TOKEN, teamId: req.teamId, projectId: req.projectId, source: { type: 'snapshot', snapshotId }, resources: { vcpus: req.vcpus }, timeout: req.timeoutMs, persistent: false, networkPolicy: setupPolicy, env: { CI: '1', GIT_TERMINAL_PROMPT: '0', AI_GATEWAY_API_KEY: 'brokered-by-sandbox-firewall' } });
    state.sandboxId = sandbox.name ?? sandbox.id;
    const phaseStart = clock.now().getTime(); let phaseAt = phaseStart;
    const phase = name => { const t = clock.now().getTime(); say(`phase ${name} ${t - phaseAt}ms (t+${t - phaseStart}ms)`); phaseAt = t; };
    phase('create');
    const sandboxDeadline = clock.now().getTime() + req.timeoutMs;
    manifest.sandboxId = state.sandboxId;
    await fs.writeFile(path.join(state.artifactDir, 'manifest.json'), JSON.stringify(manifest, null, 2));
    const home = REMOTE_HOME, remoteRepo = `${home}/repo`, remoteSpec = `${home}/input/${req.dispatchId}-spec.md`;
    const runRemote = (cmd, args = [], options = {}) => sdk.runCommand(sandbox, { cmd, args, ...options });
    const output = async (cmd, args = [], allowFail = false) => {
      const r = await runRemote(cmd, args);
      const out = await r.output('both');
      if (r.exitCode !== 0 && !allowFail) throw new Error(`remote command failed (${r.exitCode}): ${String(out).slice(-1500)}`);
      return { code: r.exitCode, out: String(out) };
    };
    const setupProbe = await output('bash', ['-lc', `git ls-remote --exit-code ${q(req.repoUrl)} HEAD >/dev/null && printf GITHUB_OK; curl -fsS -o /dev/null https://ai-gateway.vercel.sh/v1/models && printf GATEWAY_OK`], true);
    if (!setupProbe.out.includes('GATEWAY_OK')) throw new Error('setup network policy probe contradicted policy');
    if (!setupProbe.out.includes('GITHUB_OK')) {
      // No ghStsPolicy means no credential was minted: the clone has to work anonymously, and a
      // failure here is the repo, not the policy. Private repos outside vercel/* are out of scope
      // until a credential for them exists (anvil#63).
      if (!req.ghStsPolicy) throw new Error(`repository ${req.repoUrl} is not reachable anonymously; private repos outside vercel/* need a credential (anvil#63)`);
      throw new Error('setup network policy probe contradicted policy');
    }
    await output('bash', ['-lc', `mkdir -p ${q(home+'/input')} ${q(remoteRepo)} && git -C ${q(remoteRepo)} init -q && git -C ${q(remoteRepo)} remote add origin ${q(req.repoUrl)} && git -C ${q(remoteRepo)} fetch --depth=1 --filter=blob:none origin ${q(req.forkSha)} && git -C ${q(remoteRepo)} checkout --detach ${q(req.forkSha)}`]);
    phase('clone');
    const inputs = [{ path: remoteSpec, content: specContent }];
    // anvil resolves --contract relative to the source repo and copies it into the worktree, so
    // contracts land untracked under the clone; anvil's status checks run in the worktree only.
    for (const c of contractContents) inputs.push({ path: `${remoteRepo}/.anvil-input/${c.name}`, content: c.content });
    await sdk.writeFiles(sandbox, inputs);
    // Final guard after the registry pre-check: the snapshot itself records the lockfile it was built from.
    const lock = await output('bash', ['-lc', 'cat /opt/anvil-snapshot/lockfile.sha256'], true);
    const remoteHash = lock.out.trim().split(/\s/)[0];
    if (!remoteHash || remoteHash !== manifest.lockfileHash) throw new Error('snapshot lockfile hash mismatch');
    await sdk.setNetworkPolicy(sandbox, agentPolicy);
    const agentProbe = await output('bash', ['-lc', '(curl -fsS -m 5 https://github.com/ >/dev/null && echo GITHUB_OPEN || echo GITHUB_BLOCKED); (curl -fsS -m 5 https://registry.npmjs.org/ >/dev/null && echo REGISTRY_OPEN || echo REGISTRY_BLOCKED); (curl -fsS -m 5 https://ai-gateway.vercel.sh/v1/models >/dev/null && echo GATEWAY_OK || echo GATEWAY_BLOCKED)'], true);
    if (!agentProbe.out.includes('GITHUB_BLOCKED') || !agentProbe.out.includes('REGISTRY_BLOCKED') || !agentProbe.out.includes('GATEWAY_OK')) throw new Error('agent network policy probe contradicted policy');
    phase('lock-policy');
    const baseline = await output('git', ['-C', remoteRepo, 'worktree', 'list', '--porcelain']);
    worktreesBefore = parseWorktrees(baseline.out);
    manifest.remoteWorktreesBefore = worktreesBefore;
    await fs.writeFile(path.join(state.artifactDir, 'manifest.json'), JSON.stringify(manifest, null, 2));
    if (clock.isInterrupted?.()) throw new Error('controller interrupted before dispatch');
    const runBudgetMs = sandboxDeadline - clock.now().getTime() - COLLECTION_RESERVE_MS;
    if (runBudgetMs < 1_000) throw new Error('sandbox deadline reached the reserved collection window before dispatch');
    dispatched = true;
    manifest.status = 'dispatched';
    await fs.writeFile(path.join(state.artifactDir, 'manifest.json'), JSON.stringify(manifest, null, 2));
    const anvilArgs = ['run', remoteSpec, '-C', remoteRepo, '--model', req.model, '-v', '--reasoning', '--json', '--from', req.forkSha, '--gate-timeout', req.gateTimeout, ...req.gate.flatMap(x => ['--verify', x]), ...req.scopes.flatMap(x => ['--scope', x]), ...req.contracts.flatMap(x => ['--contract', `.anvil-input/${path.basename(x)}`])];
    let runError;
    const anvilStartedAt = clock.now().getTime();
    try {
      const r = await runRemote('anvil', anvilArgs, { env: { CI: '1', GIT_TERMINAL_PROMPT: '0', AI_GATEWAY_API_KEY: 'brokered-by-sandbox-firewall' }, timeout: runBudgetMs, signal: clock.signal });
      const result = await r.output('stdout').catch(() => '');
      const err = await r.output('stderr').catch(() => '');
      const safeResult=sanitize(String(result),secrets), safeErr=sanitize(String(err),secrets);
      await fs.writeFile(path.join(state.artifactDir, 'anvil-result.json'), safeResult);
      await fs.writeFile(path.join(state.artifactDir, 'anvil.log'), safeErr);
      await sdk.writeFiles(sandbox, [{ path: '/tmp/anvil-result.json', content: safeResult }, { path: '/tmp/anvil.log', content: safeErr }]);
      let parsed; try { parsed = JSON.parse(safeResult); } catch { parsed = null; }
      state.verdict = clock.isInterrupted?.() ? 'void' : parsed?.passed === true && r.exitCode === 0 ? 'green' : parsed?.passed === false || r.exitCode === 1 ? 'red' : 'void';
      exitCode = state.verdict === 'green' ? 0 : state.verdict === 'red' ? 1 : 2;
      phase('anvil');
    } catch (e) {
      runError = e; state.verdict = 'void'; exitCode = dispatched ? 2 : 4; say(`run error: ${e.message}`);
    }
    await sdk.writeFiles(sandbox, [{ path: '/tmp/timings.json', content: JSON.stringify({ anvilMs: clock.now().getTime() - anvilStartedAt, completedAt: clock.now().toISOString() }) }]);
    state.remoteWorktree = await discoverRemoteWorktree(sandbox, remoteRepo, worktreesBefore, sdk);
    manifest.remoteWorktree = state.remoteWorktree;
    await fs.writeFile(path.join(state.artifactDir, 'manifest.json'), JSON.stringify(manifest, null, 2));
    try {
      const retrievalErrors = [];
      try {
        const collect = await output('bash', ['-lc', `set -e; cd ${q(state.remoteWorktree ?? remoteRepo)}; idx=/tmp/golem-index-$$; trap 'rm -f "$idx"' EXIT; GIT_INDEX_FILE=$idx git read-tree ${q(req.forkSha)}; GIT_INDEX_FILE=$idx git add -A; GIT_INDEX_FILE=$idx git diff --cached --binary ${q(req.forkSha)} -- . ':!.anvil-input' > /tmp/golem.patch; tar -czf /tmp/anvil-state.tgz -C ${q(home)} .anvil 2>/dev/null || true; test -f /tmp/timings.json || printf '{"collectionPending":true}' > /tmp/timings.json`], true);
        if (collect.code !== 0) retrievalErrors.push(`remote collection command exit ${collect.code}`);
      } catch (e) { retrievalErrors.push(`remote collection command: ${e.message}`); }
      for (const [remote, local] of [['/tmp/golem.patch','golem.patch'], ['/tmp/anvil-state.tgz','anvil-state.tgz'], ['/tmp/anvil.log','anvil.log'], ['/tmp/anvil-result.json','anvil-result.json'], ['/tmp/timings.json','timings.json']]) {
        let lastError;
        for (let attempt = 0; attempt < 3; attempt++) {
          try { const b = await sdk.readFileToBuffer(sandbox, { path: remote }); if (!b) throw new Error('empty transfer'); await fs.writeFile(path.join(state.artifactDir, local), b); lastError = null; break; }
          catch (e) { lastError = e; }
        }
        if (lastError) { retrievalErrors.push(`${local}: ${lastError.message}`); say(`artifact retrieval failed (${local}): ${lastError.message}`); }
      }
      state.retrievalStatus = retrievalErrors.length ? `failed: ${retrievalErrors.join('; ')}` : 'complete';
      collected = true;
      if (retrievalErrors.length && exitCode === 0) exitCode = 3;
    } catch (e) { state.retrievalStatus = `failed: ${e.message}`; if (exitCode === 0) exitCode = 3; say(`collection incomplete: ${e.message}`); }
    if (state.retrievalStatus === 'complete') {
      try { await importArtifacts({ req, state, fs, git, exec, artifactDir: state.artifactDir, clock, say }); state.importStatus = 'complete'; }
      catch (e) { state.importStatus = `failed: ${e.message}`; if (exitCode === 0) exitCode = 3; say(`import failed: ${e.message}`); }
    }
    if (runError && exitCode === 0) exitCode = 2;
  } catch (e) {
    say(`controller error: ${e?.stack ?? e}`);
    if (exitCode !== 3) exitCode = dispatched ? state.verdict === 'green' ? 3 : state.verdict === 'red' ? 1 : 2 : 4;
    if (sandbox && !collected) {
      try { await collectPartial(sandbox, state, fs, say, sdk, req); collected = true; }
      catch (collectError) { state.retrievalStatus = `failed: ${collectError.message}`; }
      if (state.retrievalStatus === 'complete' && req && state.artifactDir) {
        try { await importArtifacts({ req, state, fs, git, exec, artifactDir: state.artifactDir, clock, say }); state.importStatus = 'complete'; }
        catch (e) { state.importStatus = `failed: ${e.message}`; say(`import failed: ${e.message}`); }
      }
    }
  } finally {
    if (sandbox) {
      try { await sdk.stop(sandbox); state.stopStatus = 'stopped'; say(`sandbox stopped ${clock.now().toISOString()}`); }
      catch (e) { state.stopStatus = 'failed'; state.stopError = String(e.message); say(`sandbox stop failed: ${e.message}`); }
    }
    if (req && state.artifactDir) {
      try {
        await Promise.all(pendingLogs);
        let runResult = {}; try { runResult = JSON.parse(await fs.readFile(path.join(state.artifactDir, 'anvil-result.json'), 'utf8')); } catch {}
        await fs.writeFile(path.join(state.artifactDir, 'handoff-result.json'), JSON.stringify({ exitCode, passed: state.verdict === 'green' ? true : state.verdict === 'red' ? false : null, verdict: state.verdict, voidReason: runResult.voidReason ?? (state.verdict === 'void' ? 'controller interrupted or result inconclusive' : null), attempts: runResult.attempts ?? null, cost: runResult.cost ?? runResult.usage?.cost ?? null, timeoutMs: req.timeoutMs, provenance: { repoUrl: req.repoUrl, forkSha: req.forkSha, snapshotId: state.snapshotId ?? req.snapshotId, dispatchId: req.dispatchId, summonerAddress: req.summonerAddress }, ...state }, null, 2));
      } catch (e) { say(`handoff result write failed: ${e.message}`); }
    }
  }
  return { exitCode, ...state };
}

function repoPath(url) { return new URL(url).pathname; }
function parseWorktrees(output) { return output.split('\n').filter(line => line.startsWith('worktree ')).map(line => line.slice(9)); }
async function discoverRemoteWorktree(sandbox, repo, before, sdk) {
  const command = await sdk.runCommand(sandbox, { cmd: 'git', args: ['-C', repo, 'worktree', 'list', '--porcelain'] });
  const out = String(await command.output('both'));
  if(command.exitCode!==0) throw new Error(`git worktree list failed (${command.exitCode}): ${out.slice(-1000)}`);
  const candidates = parseWorktrees(out).filter(p => p !== repo && !before.includes(p) && p.startsWith(REMOTE_HOME + '/'));
  if (candidates.length > 1) throw new Error(`ambiguous new worktrees: ${candidates.join(', ')}`);
  return candidates[0] ?? repo;
}
async function assertRegularContained(fs, base, file, label) {
  const baseStat = await fs.lstat(base);
  if (baseStat.isSymbolicLink() || !baseStat.isDirectory()) throw new Error(`${label} request directory is not a regular directory`);
  const rel = path.relative(base, file); let cursor = base;
  for (const part of rel.split(path.sep)) { cursor = path.join(cursor, part); const st = await fs.lstat(cursor); if (st.isSymbolicLink()) throw new Error(`${label} path contains a symlink: ${cursor}`); }
  const st = await fs.lstat(file); if (!st.isFile()) throw new Error(`${label} must be a regular file: ${file}`);
}
async function collectPartial(sandbox, state, fs, log, sdk, req) {
  const repo = `${REMOTE_HOME}/repo`;
  let discoveryFailed=false;
  try { state.remoteWorktree = await discoverRemoteWorktree(sandbox, repo, [], sdk); }
  catch(e) { discoveryFailed=true; state.remoteWorktree=repo; log(`remote worktree discovery failed: ${e.message}`); }
  try {
    const r = await sdk.runCommand(sandbox, { cmd: 'bash', args: ['-lc', `if [ -d ${q(state.remoteWorktree+'/.git')} ] || [ -f ${q(state.remoteWorktree+'/.git')} ]; then cd ${q(state.remoteWorktree)}; idx=/tmp/golem-index-$$; trap 'rm -f "$idx"' EXIT; GIT_INDEX_FILE=$idx git read-tree ${q(req.forkSha)} && GIT_INDEX_FILE=$idx git add -A && GIT_INDEX_FILE=$idx git diff --cached --binary ${q(req.forkSha)} -- . ':!.anvil-input' > /tmp/golem.patch; fi; tar -czf /tmp/anvil-state.tgz -C ${REMOTE_HOME} .anvil 2>/dev/null || true; : > /tmp/anvil.log; : > /tmp/anvil-result.json; test -f /tmp/timings.json || printf '{"collectionPending":true}' > /tmp/timings.json`] });
    await r.output('both');
  } catch (e) { log(`remote partial collection preparation failed: ${e.message}`); }
  let complete = true;
  for (const [remote, local] of [['/tmp/golem.patch','golem.patch'], ['/tmp/anvil-state.tgz','anvil-state.tgz'], ['/tmp/anvil.log','anvil.log'], ['/tmp/anvil-result.json','anvil-result.json'], ['/tmp/timings.json','timings.json']]) {
    try { const b = await sdk.readFileToBuffer(sandbox, { path: remote }); if (b) await fs.writeFile(path.join(state.artifactDir, local), b); else complete = false; }
    catch (e) { complete = false; log(`partial collection ${local}: ${e.message}`); }
  }
  state.retrievalStatus = complete && !discoveryFailed ? 'complete' : 'partial';
}

async function importArtifacts({ req, state, fs, git, exec, artifactDir, clock, say }) {
  const patchPath = path.join(artifactDir, 'golem.patch');
  const patch = await fs.readFile(patchPath, 'utf8');
  validatePatch(patch);
  await git.applyCheck(state.worktree, patchPath);
  await git.apply(state.worktree, patchPath);
  const archive = path.join(artifactDir, 'anvil-state.tgz');
  const stage = path.join(artifactDir, 'staging');
  await fs.mkdir(stage, { recursive: false });
  const listingResult = await exec.run('tar', ['-tzf', archive], { cwd: stage });
  const names = String(listingResult.stdout ?? '').split('\n').filter(Boolean);
  const remoteBucket = anvilBucket(`${REMOTE_HOME}/repo`), bucket = anvilBucket(path.resolve(req.localRepo));
  if (!names.some(n => n.startsWith(`.anvil/${remoteBucket}/runs/`) && n.endsWith('.json'))) throw new Error(`records archive contains no run record for bucket ${remoteBucket}`);
  for (const n of names) if (path.isAbsolute(n) || n.startsWith(String.fromCharCode(92)) || /^[A-Za-z]:[\\/]/.test(n) || n.split(/[\\/]/).includes('..')) throw new Error(`unsafe archive path: ${n}`);
  const verbose = await exec.run('tar', ['-tvzf', archive], { cwd: stage });
  if (String(verbose.stdout ?? '').split('\n').some(line => /^[lh]/.test(line))) throw new Error('archive symlink/hardlink entries are refused');
  await exec.run('tar', ['-xzf', archive, '--no-same-owner', '--no-same-permissions', '-C', stage], { cwd: stage });
  const stateHome = clock.env?.XDG_STATE_HOME ? path.join(clock.env.XDG_STATE_HOME, 'anvil') : path.join(clock.homeDir, '.anvil');
  const base = path.join(stateHome, bucket), plans = [];
  for (const kind of ['runs','sessions']) {
    const source = path.join(stage, '.anvil', remoteBucket, kind);
    if (!await fs.exists(source)) continue;
    const sourceStat = await fs.lstat(source);
    if (sourceStat.isSymbolicLink() || !sourceStat.isDirectory()) throw new Error(`unsafe ${kind} records directory`);
    // runs/ holds one JSON per run; sessions/ holds one directory per session with its JSONL
    // transcript(s) inside (anvil state-paths.ts). Both are copied flat under the local bucket.
    for (const entry of await fs.readdir(source)) {
      const from = path.join(source, entry), to = path.join(base, kind, entry);
      if (await fs.exists(to)) throw new Error(`record collision: ${to}`);
      const st = await fs.lstat(from);
      if (st.isSymbolicLink()) throw new Error(`unsafe record file: ${from}`);
      if (st.isDirectory()) {
        if (kind !== 'sessions') throw new Error(`unsafe record file: ${from}`);
        for (const child of await fs.readdir(from)) {
          const cst = await fs.lstat(path.join(from, child));
          if (cst.isSymbolicLink() || !cst.isFile()) throw new Error(`unsafe session record: ${path.join(from, child)}`);
          plans.push({ entry: child, from: path.join(from, child), to: path.join(to, child), raw: true });
        }
      } else if (st.isFile()) plans.push({ entry, from, to });
      else throw new Error(`unsafe record file: ${from}`);
    }
  }
  for (const plan of plans) {
    await fs.mkdir(path.dirname(plan.to), { recursive: true });
    if (!plan.raw && plan.entry.endsWith('.json')) {
      const rec = JSON.parse(await fs.readFile(plan.from, 'utf8')), originalBranch = rec.branch ?? 'unknown';
      rec.branch = state.branch; delete rec.pid;
      rec.note = `Imported from sandbox ${state.sandboxId} (remote branch ${originalBranch})${rec.note ? `; ${rec.note}` : ''}`;
      await fs.writeFile(plan.to, JSON.stringify(rec, null, 2));
    } else await fs.copyFile(plan.from, plan.to);
  }
  await git.verifyImported(req.localRepo, req.dispatchId);
  await fs.writeFile(path.join(artifactDir, 'handoff-result.json'), JSON.stringify({ sandboxId: state.sandboxId, branch: state.branch, worktree: state.worktree, importedAt: clock.now().toISOString() }, null, 2));
  say('artifacts imported');
}
function validatePatch(patch) {
  if (/^(?:new|old) file mode 120000$/m.test(patch)) throw new Error('symlink patch target refused');
  for (const line of patch.split('\n')) if (line.startsWith('+++ ') || line.startsWith('--- ')) {
    let name = line.slice(4).split('\t')[0]; if (name === '/dev/null') continue; name = name.replace(/^[ab]\//, ''); checkPatchPath(name);
  }
  for (const line of patch.split('\n')) {
    if (line.startsWith('diff --git ')) { const split = line.indexOf(' b/', 10); if (split < 0) throw new Error('malformed patch path header'); checkPatchPath(line.slice(10, split)); checkPatchPath(line.slice(split + 1)); }
    if (line.startsWith('rename from ') || line.startsWith('rename to ') || line.startsWith('copy from ') || line.startsWith('copy to ')) checkPatchPath(line.slice(line.indexOf(' ') + 1).replace(/^(?:from|to) /, ''));
  }
}
function checkPatchPath(name) {
  name = name.replace(/^[ab]\//, '');
  if (name.startsWith('"') || name.startsWith(String.fromCharCode(92)) || path.isAbsolute(name) || /^[A-Za-z]:[\\/]/.test(name) || name.split(/[\\/]/).includes('..')) throw new Error(`unsafe patch path: ${name}`);
}

async function main() {
  const requestPath = process.argv[2] ? path.resolve(process.argv[2]) : undefined;
  if (!requestPath) { console.error('usage: anvil-sandbox.mjs request.json'); process.exitCode = 4; return; }
  // OIDC must resolve the lane's linked Vercel project, not the caller's cwd.
  // Resolve the request path first so a relative argument still means the caller's cwd.
  process.chdir(path.dirname(fileURLToPath(import.meta.url)));
  const { Sandbox } = await import('@vercel/sandbox');
  const env = { ...process.env };
  if (!env.VERCEL_TOKEN) {
    // The login shell has no VERCEL_TOKEN; `vercel login` stores one the SDK can use. The CLI's
    // token lives 8 h and the SDK does not refresh it (replay-3 died with a 403 at Sandbox.create),
    // so when it cannot cover the whole dispatch, `vercel whoami` makes the CLI refresh its store.
    const { getAuth } = await import('@vercel/sandbox/dist/auth/index.js');
    let request = {};
    try { request = JSON.parse(await fsNative.readFile(requestPath, 'utf8')); } catch {}
    const needUntil = Date.now() + (Number(request.timeoutMs) || 60 * 60_000) + COLLECTION_RESERVE_MS;
    const covers = auth => auth?.token && (!auth.expiresAt || auth.expiresAt.getTime() > needUntil);
    let auth = getAuth();
    if (!covers(auth)) {
      try { await promisify(execFile)('vercel', ['whoami'], { stdio: ['ignore', 'pipe', 'pipe'], timeout: 60_000 }); } catch {}
      auth = getAuth();
    }
    if (!covers(auth)) { console.error('controller error: Vercel CLI credential is missing or expires before this dispatch would end; run `vercel login`'); process.exitCode = 4; return; }
    env.VERCEL_TOKEN = auth.token;
  }
  const sdk = {
    create: opts => Sandbox.create(opts),
    runCommand: (sb, opts) => sb.runCommand(opts),
    setNetworkPolicy: (sb, policy) => sb.updateNetworkPolicy(policy),
    writeFiles: (sb, files) => sb.writeFiles(files),
    readFileToBuffer: (sb, opts) => sb.readFileToBuffer(opts),
    stop: sb => sb.stop(),
  };
  const fs = { ...fsNative, exists: async p => { try { await fsNative.lstat(p); return true; } catch (e) { if (e.code === 'ENOENT') return false; throw e; } } };
  const exec = { run: async (cmd, args, opts = {}) => execFileAsync(cmd, args, { ...opts, maxBuffer: 16 * 1024 * 1024 }) };
  const git = {
    assertClean: async repo => { const { stdout } = await exec.run('git', ['status', '--porcelain'], { cwd: repo }); if (stdout.trim()) throw new Error('local repository must be clean'); },
    refuseCollision: async (repo, branch, worktree) => { const { stdout } = await exec.run('git', ['branch', '--list', branch], { cwd: repo }); if (stdout.trim() || await fs.exists(worktree)) throw new Error('branch or worktree collision'); },
    worktreeAdd: async (repo, dir, sha, branch) => exec.run('git', ['worktree', 'add', '-b', branch, dir, sha], { cwd: repo }),
    lockfileHash: async dir => { for (const f of ['pnpm-lock.yaml','package-lock.json','yarn.lock']) if (await fs.exists(path.join(dir, f))) { const { stdout } = await exec.run('shasum', ['-a', '256', path.join(dir, f)]); return stdout.split(/\s/)[0]; } throw new Error('snapshot has no supported lockfile'); },
    applyCheck: async (dir, patch) => exec.run('git', ['apply', '--check', patch], { cwd: dir }),
    apply: async (dir, patch) => exec.run('git', ['apply', patch], { cwd: dir }),
    verifyImported: async (repo, dispatchId) => { const { stdout } = await exec.run('anvil', ['status', '--json', '-C', repo], { cwd: repo }); if (!String(stdout).includes(dispatchId)) throw new Error(`anvil status did not find imported dispatch ${dispatchId}`); },
  };
  let interrupted = false;
  const abortController = new AbortController();
  const onSignal = () => { interrupted = true; abortController.abort(); };
  process.on('SIGINT', onSignal); process.on('SIGTERM', onSignal);
  const snapshots = {
    list: () => listSnapshots(),
    // build-snapshot.mjs logs to stderr (the golem log) and prints its record to stdout.
    build: async ({ repo, ref }) => {
      const { stdout } = await promisify(execFile)(process.execPath, [path.join(path.dirname(fileURLToPath(import.meta.url)), 'build-snapshot.mjs'), '--repo', repo, '--ref', ref], { stdio: ['ignore', 'pipe', 'inherit'], maxBuffer: 2 ** 24, timeout: 30 * 60_000 });
      return JSON.parse(stdout);
    },
  };
  const result = await runController(requestPath, { sdk, fs, git, exec, snapshots, credentials: { getOidcToken: () => getVercelOidcToken(), fetch: (...args) => globalThis.fetch(...args) }, clock: { now: () => new Date(), isInterrupted: () => interrupted, homeDir: os.homedir(), env, signal: abortController.signal }, log: m => console.error(m) });
  process.off('SIGINT', onSignal); process.off('SIGTERM', onSignal); process.exitCode = result.exitCode;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(e => { console.error(e); process.exitCode = 4; });
