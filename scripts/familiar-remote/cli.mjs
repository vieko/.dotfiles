#!/usr/bin/env node
// remote-familiar -- summon and watch familiars that run in Vercel Sandbox VMs.
//
//   remote-familiar start -r owner/repo [-n name] [-m model] <brief-path | ->
//   remote-familiar list [--json]
//   remote-familiar show <name>
//   remote-familiar clean <name>          delete the familiar's VM and Drive
//   remote-familiar driver install|uninstall|status|run
//
// The driver (driver.mjs, a launchd agent) does the work; this CLI only
// writes start requests and reads state. The familiar reports to the
// summoner ($PI_SESSION_ADDRESS) over pi-post, and its PR waits in the
// approval inbox (Sigil overview, macOS alert, `approvals`).

import { execFileSync, spawnSync } from 'node:child_process';
import { appendFileSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { familiarStore, paths, readJson, requestQueue, NAME } from './lib/state.mjs';
import { parseModelSpec } from './lib/model.mjs';
import { REPO } from './lib/publish.mjs';
import { vercelLogin } from './lib/auth.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const LABEL = 'dev.vieko.remote-familiars';
const PLIST = join(homedir(), 'Library', 'LaunchAgents', `${LABEL}.plist`);
const DRIVER_LOG = join(homedir(), 'scratch', 'logs', 'remote-familiars-driver.log');
const P = paths();

const die = (msg, code = 1) => { process.stderr.write(`remote-familiar: ${msg}\n`); process.exit(code); };
const [cmd, ...args] = process.argv.slice(2);

function flag(name) {
  const i = args.indexOf(name);
  if (i < 0) return undefined;
  const v = args[i + 1];
  args.splice(i, 2);
  return v;
}

export function driverAlive(now = Date.now()) {
  const d = readJson(P.driver);
  if (!d?.pid) return false;
  try { process.kill(d.pid, 0); } catch { return false; }
  return now - (d.lastSeen ?? 0) < 90_000;
}

function slug(s) {
  return String(s).toLowerCase().replace(/\.md$/, '').replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 40) || 'familiar';
}

// fnm's per-shell and per-version paths vanish (fnm-prune.sh); launchd needs a node and a PATH that stay.
const STABLE_NODE = ['/opt/homebrew/bin/node', '/usr/local/bin/node'].find((p) => existsSync(p)) ?? process.execPath;
const stablePath = () => (process.env.PATH ?? '').split(':').filter((p) => p && !p.includes('fnm_multishells')).join(':');

function plist() {
  const esc = (s) => String(s).replaceAll('&', '&amp;').replaceAll('<', '&lt;');
  return `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array><string>${esc(STABLE_NODE)}</string><string>${esc(join(here, 'driver.mjs'))}</string></array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>${esc(stablePath())}</string>
    <key>HOME</key><string>${esc(homedir())}</string>
  </dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>30</integer>
  <key>StandardOutPath</key><string>${esc(DRIVER_LOG)}</string>
  <key>StandardErrorPath</key><string>${esc(DRIVER_LOG)}</string>
</dict>
</plist>
`;
}

const domain = `gui/${process.getuid()}`;

switch (cmd) {
  case 'start': {
    const repo = flag('-r');
    const model = flag('-m');
    let name = flag('-n');
    const briefPath = args[0];
    if (!repo || !REPO.test(repo)) die('give the repository with -r owner/repo', 2);
    if (!briefPath) die('give a brief path, or - for stdin', 2);
    if (model) parseModelSpec(model);
    const brief = briefPath === '-' ? readFileSync(0, 'utf8') : readFileSync(resolve(briefPath), 'utf8');
    if (!brief.trim()) die('the brief is empty', 2);
    name ??= slug(briefPath === '-' ? repo.split('/')[1] : briefPath.split('/').pop());
    if (!NAME.test(name)) die(`name must match ${NAME}`, 2);
    if (familiarStore(P.root).get(name)) die(`a familiar named ${name} exists; pick another with -n`, 2);
    if (!driverAlive()) die('the driver is not running: remote-familiar driver install (or driver status)', 3);
    const login = await vercelLogin();
    if (!login.ok) die(login.message, 3);
    const summoner = process.env.PI_SESSION_ADDRESS;
    requestQueue(P.root).add({ name, repo, brief, ...(model ? { model } : {}), ...(summoner ? { summoner } : {}) });
    // Summon ledger, shared with summon-familiar.sh and summon-golem.sh.
    const ledger = join(homedir(), 'scratch', 'logs', 'summons.log');
    mkdirSync(dirname(ledger), { recursive: true });
    const stamp = execFileSync('date', ['+%Y-%m-%dT%H:%M:%S%z'], { encoding: 'utf8' }).trim();
    appendFileSync(ledger, `${stamp} kind=familiar lane=remote vessel=${model ?? 'driver'} window=rfam-${name} repo=${repo}${summoner ? ` by=${summoner}` : ''}${briefPath !== '-' ? ` brief=${resolve(briefPath)}` : ''}\n`);
    let rec;
    for (let i = 0; i < 60 && !(rec = familiarStore(P.root).get(name))?.sessionId; i++) {
      if (rec?.status === 'failed') break;
      spawnSync('sleep', ['1']);
    }
    if (!rec) die(`the driver did not take the request in 60 s; see ${DRIVER_LOG}`, 4);
    if (rec.status === 'failed') die(`the driver refused ${name}: ${rec.error}`, 4);
    process.stdout.write(`summoned: remote familiar ${name} on ${repo}, model ${rec.model}\n`);
    process.stdout.write(`session: ${rec.sessionId} (pi-post ${rec.address}, sandbox ${rec.sandbox})\n`);
    process.stdout.write(`log: ~/scratch/logs/rfam-${name}.log\n`);
    process.stdout.write(summoner ? `report: to ${summoner} over pi-post\n` : 'report: no PI_SESSION_ADDRESS, the report stays in the familiar record\n');
    break;
  }
  case 'list': {
    const rows = familiarStore(P.root).list().sort((a, b) => (b.startedAt ?? 0) - (a.startedAt ?? 0));
    if (args.includes('--json')) { process.stdout.write(`${JSON.stringify(rows.map(({ brief, cursor, ...r }) => r))}\n`); break; }
    if (!rows.length) { process.stdout.write('no remote familiars\n'); break; }
    for (const r of rows) process.stdout.write(`${r.name.padEnd(28)} ${String(r.status).padEnd(17)} ${r.repo}${r.published ? ` ${r.published.pr}` : ''}\n`);
    break;
  }
  case 'show': {
    const rec = familiarStore(P.root).get(args[0] ?? '');
    if (!rec) die(`no remote familiar ${args[0]}`, 3);
    const { cursor, ...shown } = rec;
    process.stdout.write(`${JSON.stringify(shown, null, 2)}\n`);
    break;
  }
  case 'clean': {
    const rec = familiarStore(P.root).get(args[0] ?? '');
    if (!rec?.sessionId) die(`no remote familiar ${args[0]} with a session`, 3);
    if (rec.status !== 'done' && rec.status !== 'failed') die(`${rec.name} is ${rec.status}; clean it when it is done`, 4);
    const script = `const { deleteSessionSandbox } = await import('durable-harness/sandbox'); console.log(JSON.stringify(await deleteSessionSandbox(${JSON.stringify(rec.sessionId)})));`;
    const r = spawnSync(process.execPath, ['--input-type=module', '-e', script], { cwd: here, encoding: 'utf8' });
    if (r.status !== 0) die(`delete failed: ${r.stderr.trim().slice(-500)}`, 4);
    familiarStore(P.root).update(rec.name, { cleaned: Date.now() });
    process.stdout.write(r.stdout);
    break;
  }
  case 'driver': {
    const sub = args[0];
    if (sub === 'install') {
      if (process.platform !== 'darwin') die('the driver runs as a launchd agent on macOS');
      mkdirSync(dirname(PLIST), { recursive: true });
      mkdirSync(dirname(DRIVER_LOG), { recursive: true });
      spawnSync('launchctl', ['bootout', `${domain}/${LABEL}`], { stdio: 'ignore' });
      spawnSync('sleep', ['3']);
      // One driver only: a second one on the same world would drive the same sessions.
      if (driverAlive()) die(`a driver outside launchd runs (pid ${readJson(P.driver).pid}); stop it first`, 4);
      writeFileSync(PLIST, plist());
      const r = spawnSync('launchctl', ['bootstrap', domain, PLIST], { encoding: 'utf8' });
      if (r.status !== 0) die(`launchctl bootstrap failed: ${r.stderr.trim()}`);
      process.stdout.write(`installed ${LABEL}; log ${DRIVER_LOG}\n`);
    } else if (sub === 'uninstall') {
      spawnSync('launchctl', ['bootout', `${domain}/${LABEL}`], { stdio: 'ignore' });
      rmSync(PLIST, { force: true });
      process.stdout.write(`removed ${LABEL}\n`);
    } else if (sub === 'status') {
      const d = readJson(P.driver);
      process.stdout.write(driverAlive() ? `running: pid ${d.pid}, model ${d.model}, review ${d.review}\n` : `not running${existsSync(PLIST) ? ' (launchd agent installed; see the log)' : ''}; log ${DRIVER_LOG}\n`);
      const login = await vercelLogin({ refresh: false });
      process.stdout.write(login.ok ? `vercel login: ${login.left === Infinity ? 'no expiry' : `${login.left} minutes left`}\n` : `vercel login: ${login.message}\n`);
      if (!driverAlive() || !login.ok) process.exitCode = 1;
    } else if (sub === 'run') {
      const r = spawnSync(process.execPath, [join(here, 'driver.mjs')], { stdio: 'inherit' });
      process.exitCode = r.status ?? 1;
    } else die('driver install|uninstall|status|run', 2);
    break;
  }
  default:
    process.stdout.write(readFileSync(fileURLToPath(import.meta.url), 'utf8').split('\n').slice(1, 14).map((l) => l.replace(/^\/\/ ?/, '')).join('\n') + '\n');
    if (cmd && cmd !== 'help' && cmd !== '--help') process.exitCode = 2;
}
