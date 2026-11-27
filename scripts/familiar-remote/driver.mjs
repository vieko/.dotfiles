#!/usr/bin/env node
// The remote-familiar driver: one long-lived process on this Mac (a launchd
// agent, `remote-familiar driver install`) that drives every remote familiar.
// Each familiar is a durable-harness Pi session on world-local with its own
// Vercel Sandbox VM and Drive; the agent loop and the model calls run here,
// the commands in the VM. One driver only: a session with no process driving
// it stays "model running" until something drives it again.

import { execFileSync, spawn } from 'node:child_process';
import { appendFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { familiarStore, paths, registerSession, addressOf, requestQueue, writeJson, NAME } from './lib/state.mjs';
import { resolveModel, parseModelSpec } from './lib/model.mjs';
import { reportTool, requestPublishTool, REPO_DIR } from './lib/tools.mjs';
import { githubClient, REPO } from './lib/publish.mjs';
import { instructions, firstPrompt } from './lib/prompt.mjs';

const here = dirname(fileURLToPath(import.meta.url));
// OIDC for the Sandbox SDK resolves the project from the cwd's .vercel link (vieko-golem-sandbox).
process.chdir(here);

const approvalsLib = join(here, '..', '..', 'pi', '.pi', 'agent', 'extensions', 'destructive-guard', 'approvals.mjs');
const approvals = await import(approvalsLib);
const { createWorld } = await import('@workflow/world-local');
const { QUEUE_PREFIX, sandbox } = await import('durable-harness');
const { pi, createCodingTools } = await import('durable-harness/pi');
const { sandboxName } = await import('durable-harness/sandbox');
const { Sandbox } = await import('@vercel/sandbox');
const { createModels } = await import('@earendil-works/pi-ai');
const { vercelAIGatewayProvider } = await import('@earendil-works/pi-ai/providers/vercel-ai-gateway');

const P = paths();
mkdirSync(P.world, { recursive: true, mode: 0o700 });
const LOGS = join(homedir(), 'scratch', 'logs');
mkdirSync(LOGS, { recursive: true });
const store = familiarStore(P.root);
const queue = requestQueue(P.root);
const log = (...a) => console.error(new Date().toISOString(), ...a);
const familiarLog = (name, line) => { try { appendFileSync(join(LOGS, `rfam-${name}.log`), `${line}\n`); } catch {} };
const logDir = (name) => join(LOGS, `rfam-${name}`);

// ---- credentials, resolved here and never sent to the VM ----
let gatewayKey = process.env.AI_GATEWAY_API_KEY;
function getGatewayKey() {
  if (!gatewayKey) gatewayKey = execFileSync('pi', ['auth', 'print-api-key', '--provider', 'vercel-ai-gateway'], { encoding: 'utf8', timeout: 30_000 }).trim();
  return gatewayKey;
}
let ghToken;
function getGhToken() {
  ghToken ??= execFileSync('gh', ['auth', 'token'], { encoding: 'utf8', timeout: 30_000 }).trim();
  return ghToken;
}
const secrets = () => [gatewayKey, ghToken].filter(Boolean);

// ---- models ----
const models = createModels();
models.setProvider(vercelAIGatewayProvider());
const pinned = (id) => models.getModel('vercel-ai-gateway', id);
const MODEL_SPEC = process.env.REMOTE_FAMILIAR_MODEL || 'fable';
const REVIEW_SPEC = process.env.REMOTE_FAMILIAR_REVIEW_MODEL || 'haiku';
const main = resolveModel(MODEL_SPEC, { pinned });
const reviewer = resolveModel(REVIEW_SPEC, { pinned });

async function ask(prompt) {
  const msg = await models.completeSimple(reviewer.model, { messages: [{ role: 'user', content: prompt, timestamp: Date.now() }] }, { apiKey: getGatewayKey(), reasoning: reviewer.thinkingLevel === 'off' ? undefined : reviewer.thinkingLevel });
  if (msg.stopReason === 'error') throw new Error(msg.errorMessage ?? 'review model error');
  return msg.content.filter((c) => c.type === 'text').map((c) => c.text).join('');
}

// ---- the VM, as the host tools see it ----
async function vmFor(runId) {
  const sb = await Sandbox.get({ name: sandboxName(runId) });
  // The harness runs the model's commands as `agent`; staging as that user keeps .git writable for it.
  const run = async (script) => {
    const r = await sb.runCommand({ cmd: 'sudo', args: ['-u', 'agent', '-H', '--', 'bash', '-c', script] });
    const out = String(await r.output('stdout'));
    if (r.exitCode !== 0) return { code: r.exitCode, out: `${out}\n${String(await r.output('stderr'))}` };
    return { code: 0, out };
  };
  return {
    run,
    readFile: async (path) => {
      const r = await run(`base64 -w0 '${path.replaceAll("'", "'\\''")}'`);
      if (r.code !== 0) throw new Error(`read ${path}: ${r.out.slice(-300)}`);
      return Buffer.from(r.out.trim(), 'base64');
    },
  };
}

function piPost(to, from, body) {
  return new Promise((resolve, reject) => {
    const bin = join(homedir(), '.pi', 'agent', 'post', 'bin', 'pi-post');
    const child = spawn(bin, ['send', '--to', to, '--from', from], { stdio: ['pipe', 'ignore', 'pipe'] });
    let err = '';
    child.stderr.on('data', (d) => { err += d; });
    child.on('error', reject);
    child.on('close', (code) => (code === 0 ? resolve() : reject(new Error(`pi-post exit ${code}: ${err.trim()}`))));
    child.stdin.end(body);
  });
}
function alert(id) {
  try { spawn(join(homedir(), '.scripts', 'approvals'), ['prompt', id], { detached: true, stdio: 'ignore' }).unref(); } catch {}
}

// ---- the agent ----
const bySession = new Map(store.list().filter((f) => f.sessionId).map((f) => [f.sessionId, f.name]));
const familiarOf = (runId) => { const name = bySession.get(runId); return name ? store.get(name) : undefined; };
const deps = {
  familiarOf, vmFor, approvals, ask, github: githubClient({ token: getGhToken() }),
  send: piPost, update: (name, patch) => store.update(name, patch), alert, logDir, secrets,
};

export const NETWORK = { allow: ['github.com', 'api.github.com', 'codeload.github.com', '*.githubusercontent.com', 'registry.npmjs.org', 'fonts.googleapis.com', 'fonts.gstatic.com'] };
const box = sandbox({
  vcpus: 4,
  idleMs: 10 * 60_000,
  commandTimeoutMs: 20 * 60_000,
  network: NETWORK,
  budget: { sessionUsd: Number(process.env.REMOTE_FAMILIAR_SESSION_USD || 25), vmSeconds: Number(process.env.REMOTE_FAMILIAR_VM_SECONDS || 3 * 3600) },
});
const world = createWorld({ dataDir: P.world, recoverActiveRuns: true });
const agent = pi({
  world,
  name: 'remote-familiar',
  model: main.model,
  streamFn: models.streamSimple.bind(models),
  thinkingLevel: main.thinkingLevel,
  getApiKey: () => getGatewayKey(),
  instructions: instructions(),
  tools: [...createCodingTools(box), reportTool(deps), requestPublishTool(deps)],
});
world.registerHandler(QUEUE_PREFIX, agent.sessions.handler);
await world.start?.();
log(`driver ${process.pid} up: model ${main.spec}, review ${reviewer.spec}, world ${P.world}`);

// ---- per-familiar watch: log, status, fallback report ----
const ACTIVE = new Set(['starting', 'running', 'waiting-approval']);
const watching = new Set();

function heartbeat(rec, live = true) {
  if (!rec?.address || !rec.sessionId) return;
  registerSession({ address: rec.address, sessionId: rec.sessionId, name: `rfam-${rec.name}`, cwd: `github.com/${rec.repo}`, parent: rec.summoner, startedAt: rec.startedAt, live });
}

async function finish(name, lastText) {
  let rec = store.get(name);
  if (!rec) return;
  if (!rec.reported && rec.summoner) {
    const body = `Remote familiar ${name} (${rec.repo}) went idle without calling report. Its last message:\n\n${(lastText || '(no text)').slice(-4000)}`;
    try { await piPost(rec.summoner, `rfam:${name}`, body); } catch (e) { log(`fallback report for ${name} failed: ${e.message}`); }
  }
  rec = store.update(name, { status: 'done', endedAt: Date.now() });
  heartbeat(rec, false);
  familiarLog(name, `[driver] done`);
}

async function watch(name) {
  if (watching.has(name)) return;
  watching.add(name);
  try {
    const rec = store.get(name);
    let text = '';
    let worked = false;
    const opts = rec.cursor ? { cursor: rec.cursor } : { startIndex: 0 };
    let n = 0;
    for await (const { value, cursor } of agent.sessions.liveEntries(rec.sessionId, opts)) {
      const e = /** @type {any} */ (value);
      if (e.type === 'text') text += e.delta ?? e.text ?? '';
      if (e.type === 'tool_start') {
        worked = true;
        const tool = e.name ?? e.toolName;
        familiarLog(name, `[tool] ${tool} ${JSON.stringify(e.args ?? e.input ?? {}).slice(0, 300)}`);
        if (tool === 'request_publish') store.update(name, { status: 'waiting-approval' });
        if (text.trim()) { familiarLog(name, text.trim()); text = ''; }
      }
      if (e.type === 'tool_end' && (e.name ?? e.toolName) === 'request_publish') store.update(name, { status: 'running' });
      if (e.type === 'error') familiarLog(name, `[error] ${JSON.stringify(e).slice(0, 500)}`);
      if (e.type === 'turn') worked = true;
      if (++n % 20 === 0) store.update(name, { cursor });
      if (e.type === 'idle' && worked) {
        if (text.trim()) familiarLog(name, text.trim());
        store.update(name, { cursor });
        await finish(name, text || rec.lastText);
        break;
      }
      if (e.type === 'text' && text.length > 8000) { store.update(name, { lastText: text.slice(-4000) }); }
    }
  } catch (e) {
    log(`watch ${name}: ${e?.stack ?? e}`);
    store.update(name, { status: 'failed', error: String(e?.message ?? e) });
    heartbeat(store.get(name), false);
  } finally {
    watching.delete(name);
  }
}

async function fetchAgentsMd(repo) {
  try {
    const res = await fetch(`https://api.github.com/repos/${repo}/contents/AGENTS.md`, { headers: { Authorization: `Bearer ${getGhToken()}`, Accept: 'application/vnd.github.raw' } });
    return res.ok ? (await res.text()).slice(0, 40_000) : undefined;
  } catch { return undefined; }
}

async function startFamiliar(req) {
  const name = req.name;
  if (!NAME.test(name) || !REPO.test(req.repo ?? '') || !String(req.brief ?? '').trim()) { log(`refused request ${name}: bad name, repo or brief`); return; }
  if (store.get(name)) { log(`refused request ${name}: a familiar with that name exists`); return; }
  if (req.model && parseModelSpec(req.model).id !== main.model.id) {
    store.put({ name, repo: req.repo, status: 'failed', error: `this driver runs ${main.spec}; restart it with REMOTE_FAMILIAR_MODEL=${req.model}`, startedAt: Date.now() });
    return;
  }
  store.put({ name, repo: req.repo, brief: req.brief, summoner: req.summoner, model: main.spec, status: 'starting', startedAt: Date.now() });
  try {
    const agentsMd = await fetchAgentsMd(req.repo);
    const { sessionId } = await agent.sessions.start({ config: { familiar: name, repo: req.repo } });
    const address = addressOf(sessionId);
    bySession.set(sessionId, name);
    const rec = store.update(name, { sessionId, address, sandbox: sandboxName(sessionId), status: 'running' });
    heartbeat(rec);
    familiarLog(name, `[driver] session ${sessionId} address ${address} model ${main.spec}`);
    await agent.sessions.send(sessionId, firstPrompt({ name, repo: req.repo, brief: req.brief, agentsMd, repoDir: REPO_DIR }));
    watch(name);
    log(`started ${name} (${req.repo}) as ${sessionId}`);
  } catch (e) {
    log(`start ${name}: ${e?.stack ?? e}`);
    store.update(name, { status: 'failed', error: String(e?.message ?? e) });
  }
}

// Recover: re-watch familiars that were active when the driver stopped.
for (const rec of store.list()) if (ACTIVE.has(rec.status) && rec.sessionId) watch(rec.name);

let stopping = false;
let ticks = 0;
const tick = async () => {
  if (stopping) return;
  for (const req of queue.take()) await startFamiliar(req);
  // pi-post heartbeats every 30 s; the overview calls a record stale after 3 minutes.
  if (ticks++ % 15 === 0) {
    writeJson(P.driver, { pid: process.pid, model: main.spec, review: reviewer.spec, lastSeen: Date.now() });
    for (const rec of store.list()) if (ACTIVE.has(rec.status)) heartbeat(rec);
  }
};
await tick();
const pollTimer = setInterval(() => tick().catch((e) => log(`tick: ${e?.stack ?? e}`)), 2_000);

const shutdown = () => {
  stopping = true;
  clearInterval(pollTimer);
  for (const rec of store.list()) if (ACTIVE.has(rec.status)) heartbeat(rec, false);
  try { writeFileSync(P.driver, `${JSON.stringify({ pid: null, lastSeen: Date.now() })}\n`); } catch {}
  log('driver stopping');
  process.exit(0);
};
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
