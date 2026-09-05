#!/usr/bin/env node
// Weekly pi session audit: deterministic numbers from ~/.pi/agent/sessions/**.
// Usage: node audit.mjs [--since 7d|2026-08-31] [--until ISO] [--json out.json] [--top 15]
// Prints a markdown report to stdout. The interpretation (patterns, footguns,
// opportunities) is the agent's job; see ../SKILL.md.

import { readdirSync, readFileSync, statSync, writeFileSync, existsSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";

const args = process.argv.slice(2);
const opt = (name, dflt) => {
	const i = args.indexOf(`--${name}`);
	return i >= 0 ? args[i + 1] : dflt;
};
const parseSince = (v) => {
	const m = /^(\d+)([dhm])$/.exec(v);
	if (m) return Date.now() - Number(m[1]) * { d: 86_400_000, h: 3_600_000, m: 60_000 }[m[2]];
	// A bare YYYY-MM-DD is local midnight, not UTC midnight.
	const t = new Date(/^\d{4}-\d{2}-\d{2}$/.test(v) ? `${v}T00:00:00` : v).getTime();
	if (Number.isNaN(t)) throw new Error(`--since: expected 7d/24h/90m or an ISO date, got ${v}`);
	return t;
};
const since = parseSince(opt("since", "7d"));
const until = opt("until") ? parseSince(opt("until")) : Date.now();
const topN = Number(opt("top", "15"));
const jsonOut = opt("json");
const TZ = process.env.AUDIT_TZ ?? "America/Edmonton";

// Pricing: pi bills 1h cache writes at the 5m rate via the gateway (pi#9210).
// Anthropic charges 2x input for 1h writes; with PI_CACHE_RETENTION=long every
// write is a 1h write. `trueCost` corrects that using the model catalog.
const catalogPath = (() => {
	const roots = [
		process.env.PI_PACKAGE_ROOT,
		join(homedir(), ".npm-global/lib/node_modules/@earendil-works/pi-coding-agent"),
		"/usr/local/lib/node_modules/@earendil-works/pi-coding-agent",
		"/opt/homebrew/lib/node_modules/@earendil-works/pi-coding-agent",
	].filter(Boolean);
	for (const r of roots) {
		const p = join(r, "node_modules/@earendil-works/pi-ai/dist/providers/data/vercel-ai-gateway.json");
		if (existsSync(p)) return p;
	}
	return null;
})();
const catalog = catalogPath ? Object.assign({}, ...Object.values(JSON.parse(readFileSync(catalogPath, "utf8")))) : {};
const longRetention = (process.env.PI_CACHE_RETENTION ?? "long") === "long";
const trueCostOf = (m, u) => {
	const c = catalog[m.model]?.cost;
	if (!c || m.api !== "anthropic-messages" || !longRetention) return u.cost.total;
	// replace pi's 5m-rate write charge with the 1h rate (2x input)
	return u.cost.total - u.cost.cacheWrite + (u.cacheWrite * c.input * 2) / 1e6;
};

const root = join(homedir(), ".pi/agent/sessions");
const mt = (t) => new Date(t).toLocaleString("en-CA", { timeZone: TZ, hour12: false }).slice(0, 16);
const day = (t) => new Date(t).toLocaleDateString("en-CA", { timeZone: TZ });
const r2 = (x) => +x.toFixed(2);
const usd = (x) => `$${x.toFixed(0)}`;
const shortDir = (d) => d.replace(/^--Users-[^-]+-/, "").replace(/--$/, "").replace(/^private-tmp-/, "tmp/");

const sessions = [];
const totals = { turns: 0, user: 0, toolCalls: 0, toolErrors: 0, pi: 0, tru: 0, byType: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 } };
const byDay = {};
const byModel = {};
const tools = {};
const toolErrCats = {};
const hardStops = [];
const ctxBuckets = {};
const misses = { first: [], idle: [], unexplained: [], compaction: [], modelswitch: [] };
const ttl = { premium: 0, saved: 0 };
const editByModel = {};
const openers = [];
const gapHist = {};

for (const dir of readdirSync(root)) {
	let files;
	try {
		files = readdirSync(join(root, dir)).filter((f) => f.endsWith(".jsonl"));
	} catch {
		continue;
	}
	for (const f of files) {
		const p = join(root, dir, f);
		if (statSync(p).mtimeMs < since) continue;
		const L = readFileSync(p, "utf8")
			.split("\n")
			.filter(Boolean)
			.map((l) => {
				try {
					return JSON.parse(l);
				} catch {
					return null;
				}
			})
			.filter(Boolean);
		const s = { dir: shortDir(dir), file: f.slice(0, 16), start: null, user: 0, turns: 0, toolCalls: 0, toolErrors: 0, pi: 0, tru: 0, ctxSum: 0, maxCtx: 0, models: new Set(), firstPrompt: "", inWindow: false };
		const calls = new Map();
		let prev = null;
		let prevIdx = -1;
		for (let i = 0; i < L.length; i++) {
			const e = L[i];
			if (e.type !== "message") continue;
			const m = e.message;
			const ts = new Date(e.timestamp).getTime();
			if (m.role === "user") {
				const txt = (m.content ?? []).filter((c) => c.type === "text").map((c) => c.text).join(" ").replace(/\s+/g, " ");
				if (!s.firstPrompt) s.firstPrompt = txt.slice(0, 120);
				if (ts >= since && ts <= until) {
					s.user++;
					totals.user++;
					if (!txt.startsWith("Message from process")) openers.push(txt.slice(0, 60));
				}
				continue;
			}
			if (m.role === "toolResult") {
				if (ts < since || ts > until) continue;
				if (m.isError) {
					s.toolErrors++;
					totals.toolErrors++;
					const call = calls.get(m.toolCallId) ?? {};
					const txt = (m.content ?? []).map((c) => c.text ?? "").join(" ").slice(0, 300);
					let cat = "other";
					if (/Validation failed/i.test(txt)) cat = "schema validation";
					else if (/oldText|No match|did not match|not found in/i.test(txt)) cat = "edit: oldText mismatch";
					else if (/exit code|exited with|Command exited/i.test(txt)) cat = "bash: nonzero exit";
					else if (/timed? ?out/i.test(txt)) cat = "timeout";
					else if (/ENOENT|No such file/i.test(txt)) cat = "missing file";
					const k = `${call.name ?? "?"} / ${cat}`;
					toolErrCats[k] = (toolErrCats[k] ?? 0) + 1;
				}
				continue;
			}
			if (m.role !== "assistant") continue;
			for (const c of m.content ?? []) if (c.type === "toolCall") calls.set(c.id, { name: c.name });
			const u = m.usage;
			if (!u?.cost) continue;
			if (ts < since || ts > until) {
				prev = e;
				prevIdx = i;
				continue;
			}
			s.inWindow = true;
			if (!s.start) s.start = ts;
			const model = (m.model ?? "?").split("/").pop();
			s.models.add(model);
			const tru = trueCostOf(m, u);
			s.turns++;
			s.pi += u.cost.total;
			s.tru += tru;
			totals.turns++;
			totals.pi += u.cost.total;
			totals.tru += tru;
			for (const k of Object.keys(totals.byType)) totals.byType[k] += u.cost[k] ?? 0;
			const d = day(ts);
			byDay[d] ??= { turns: 0, pi: 0, tru: 0, sessions: new Set() };
			byDay[d].turns++;
			byDay[d].pi += u.cost.total;
			byDay[d].tru += tru;
			byDay[d].sessions.add(p);
			byModel[model] ??= { turns: 0, pi: 0, tru: 0, sessions: new Set(), eligible: 0, unexplained: 0 };
			byModel[model].turns++;
			byModel[model].pi += u.cost.total;
			byModel[model].tru += tru;
			byModel[model].sessions.add(p);
			for (const c of m.content ?? []) {
				if (c.type !== "toolCall") continue;
				s.toolCalls++;
				totals.toolCalls++;
				tools[c.name] = (tools[c.name] ?? 0) + 1;
				if (c.name === "edit") {
					editByModel[model] ??= { edits: 0, malformed: 0 };
					editByModel[model].edits++;
					const ed = c.arguments?.edits;
					if (Array.isArray(ed) && ed.some((x) => !x || Object.keys(x).length === 0 || x.newText === undefined)) editByModel[model].malformed++;
				}
			}
			if (m.stopReason === "error" || m.stopReason === "aborted") hardStops.push({ when: mt(ts), dir: s.dir, model, stop: m.stopReason, err: (m.errorMessage ?? "").slice(0, 80) });
			const ctx = u.input + u.cacheRead + u.cacheWrite;
			s.ctxSum += ctx;
			if (ctx > s.maxCtx) s.maxCtx = ctx;
			const b = ctx < 50e3 ? "<50K" : ctx < 100e3 ? "50-100K" : ctx < 200e3 ? "100-200K" : ctx < 400e3 ? "200-400K" : ">=400K";
			ctxBuckets[b] ??= { turns: 0, pi: 0, tru: 0 };
			ctxBuckets[b].turns++;
			ctxBuckets[b].pi += u.cost.total;
			ctxBuckets[b].tru += tru;
			// cache economics
			const c = catalog[m.model]?.cost;
			if (c && m.api === "anthropic-messages" && longRetention) {
				ttl.premium += (u.cacheWrite * (c.input * 2 - c.cacheWrite)) / 1e6;
				const gap = prev ? (ts - new Date(prev.timestamp).getTime()) / 60000 : null;
				if (gap !== null && gap >= 5 && gap < 60 && u.cacheWrite <= 0.5 * ctx) ttl.saved += (u.cacheRead * (c.cacheWrite - c.cacheRead)) / 1e6;
			}
			if (prev) {
				const gap = (ts - new Date(prev.timestamp).getTime()) / 60000;
				const gb = gap < 5 ? "<5m" : gap < 60 ? "5-60m" : gap < 24 * 60 ? "1-24h" : ">24h";
				gapHist[gb] = (gapHist[gb] ?? 0) + 1;
			}
			if (ctx > 20e3 && u.cacheWrite > 0.5 * ctx) {
				const between = L.slice(prevIdx + 1, i);
				let k = "unexplained";
				if (!prev) k = "first";
				else if (prev.message.model !== m.model || between.some((x) => x.type === "model_change")) k = "modelswitch";
				else if (between.some((x) => x.type === "compaction")) k = "compaction";
				else if ((ts - new Date(prev.timestamp).getTime()) / 60000 >= 60) k = "idle";
				misses[k].push({ ts, when: mt(ts), dir: s.dir, model, ctxK: Math.round(ctx / 1000), pi: u.cost.total, tru, gapMin: prev ? Math.round((ts - new Date(prev.timestamp).getTime()) / 60000) : null });
			} else if (prev && prev.message.model === m.model && ctx > 20e3) {
				// eligible for an unexplained miss but hit the cache
			}
			if (prev && prev.message.model === m.model && ctx > 20e3 && (ts - new Date(prev.timestamp).getTime()) / 60000 < 60) {
				byModel[model].eligible++;
				if (u.cacheWrite > 0.5 * ctx && !L.slice(prevIdx + 1, i).some((x) => x.type === "compaction" || x.type === "model_change")) byModel[model].unexplained++;
			}
			prev = e;
			prevIdx = i;
		}
		if (s.inWindow) sessions.push({ ...s, models: [...s.models], avgCtxK: s.turns ? Math.round(s.ctxSum / s.turns / 1000) : 0, maxCtxK: Math.round(s.maxCtx / 1000) });
	}
}

// clustering of unexplained misses across sessions (shared momentary cause)
const un = misses.unexplained.sort((a, b) => a.ts - b.ts);
let clustered = 0;
for (let i = 0; i < un.length; i++) if (un.some((o, j) => j !== i && o.dir + o.when !== un[i].dir + un[i].when && Math.abs(o.ts - un[i].ts) < 180_000 && o.dir !== un[i].dir)) clustered++;

// ---- report ----
const out = [];
const P = (s = "") => out.push(s);
P(`# pi session audit: ${mt(since)} to ${mt(until)} (${TZ})`);
P();
P(`Sessions with turns in window: ${sessions.length}. Assistant turns: ${totals.turns}. User turns: ${totals.user}. Tool calls: ${totals.toolCalls} (errors ${totals.toolErrors}).`);
P(`Spend: pi-reported ${usd(totals.pi)}, true ≈ ${usd(totals.tru)}${longRetention ? " (1h cache writes repriced at 2x input; pi#9210)" : ""}. By type (pi-reported): input ${usd(totals.byType.input)}, output ${usd(totals.byType.output)}, cacheRead ${usd(totals.byType.cacheRead)}, cacheWrite ${usd(totals.byType.cacheWrite)}.`);
if (longRetention) P(`1h TTL: premium paid ≈ ${usd(ttl.premium)}, rewrites avoided on 5-60m gaps ≈ ${usd(ttl.saved)}, net ${ttl.saved - ttl.premium >= 0 ? "+" : ""}${usd(ttl.saved - ttl.premium)}.`);
P();
P(`## Per day`);
P(`| day | sessions | turns | pi $ | true $ |`);
P(`|---|---|---|---|---|`);
for (const [d, v] of Object.entries(byDay).sort()) P(`| ${d} | ${v.sessions.size} | ${v.turns} | ${usd(v.pi)} | ${usd(v.tru)} |`);
P();
P(`## Models`);
P(`| model | sessions | turns | true $ | unexplained-miss rate |`);
P(`|---|---|---|---|---|`);
for (const [m, v] of Object.entries(byModel).sort((a, b) => b[1].tru - a[1].tru)) P(`| ${m} | ${v.sessions.size} | ${v.turns} | ${usd(v.tru)} | ${v.eligible ? `${((100 * v.unexplained) / v.eligible).toFixed(2)}% (${v.unexplained}/${v.eligible})` : "-"} |`);
P();
P(`## Context size`);
P(`| ctx | turns | share of turns | true $ | share of spend |`);
P(`|---|---|---|---|---|`);
for (const b of ["<50K", "50-100K", "100-200K", "200-400K", ">=400K"]) {
	const v = ctxBuckets[b];
	if (!v) continue;
	P(`| ${b} | ${v.turns} | ${((100 * v.turns) / totals.turns).toFixed(0)}% | ${usd(v.tru)} | ${((100 * v.tru) / totals.tru).toFixed(0)}% |`);
}
P(`Gap since previous turn: ${JSON.stringify(gapHist)}.`);
P();
P(`## Full-prefix cache misses (cacheWrite > 50% of ctx, ctx > 20K)`);
P(`| cause | n | true $ | avg ctx |`);
P(`|---|---|---|---|`);
for (const [k, arr] of Object.entries(misses)) if (arr.length) P(`| ${k} | ${arr.length} | ${usd(arr.reduce((a, x) => a + x.tru, 0))} | ${Math.round(arr.reduce((a, x) => a + x.ctxK, 0) / arr.length)}K |`);
P(`Unexplained = same model, gap < 1h, no compaction. ${clustered} of ${un.length} sit within 3 min of an unexplained miss in another session (shared momentary cause: backend switch or transport retry).`);
if (un.length) {
	P();
	P(`Unexplained, most expensive first:`);
	for (const x of [...un].sort((a, b) => b.tru - a.tru).slice(0, 8)) P(`- ${x.when} ${x.dir} ${x.model} ctx=${x.ctxK}K gap=${x.gapMin}m ≈ $${x.tru.toFixed(2)}`);
}
P();
P(`## Tools`);
P(Object.entries(tools).sort((a, b) => b[1] - a[1]).map(([k, v]) => `${k}:${v}`).join(", "));
P(`Tool errors by category:`);
for (const [k, v] of Object.entries(toolErrCats).sort((a, b) => b[1] - a[1])) P(`- ${v} ${k}`);
P(`Edit tool health by model (malformed = empty edit or missing newText):`);
for (const [m, v] of Object.entries(editByModel)) P(`- ${m}: ${v.malformed}/${v.edits}${v.edits ? ` (${((100 * v.malformed) / v.edits).toFixed(1)}%)` : ""}`);
P();
P(`## Hard stops (${hardStops.length})`);
for (const h of hardStops) P(`- ${h.when} ${h.dir} ${h.model} ${h.stop} ${h.err}`);
P();
P(`## Top sessions by true cost`);
P(`| start | dir | user | turns | tools | err | true $ | avg ctx | max ctx | models | opener |`);
P(`|---|---|---|---|---|---|---|---|---|---|---|`);
for (const s of [...sessions].sort((a, b) => b.tru - a.tru).slice(0, topN)) P(`| ${mt(s.start).slice(5)} | ${s.dir} | ${s.user} | ${s.turns} | ${s.toolCalls} | ${s.toolErrors} | ${usd(s.tru)} | ${s.avgCtxK}K | ${s.maxCtxK}K | ${s.models.join(",")} | ${s.firstPrompt.slice(0, 70).replace(/\|/g, "/")} |`);
P();
P(`## Openers (first 4 words, top 12)`);
const op = {};
for (const o of openers) {
	const k = o.toLowerCase().split(/\s+/).slice(0, 4).join(" ");
	op[k] = (op[k] ?? 0) + 1;
}
for (const [k, v] of Object.entries(op).sort((a, b) => b[1] - a[1]).slice(0, 12)) if (v > 1) P(`- ${v}x "${k}"`);
P();
P(`## Constructs`);
const summons = join(homedir(), "scratch/logs/summons.log");
if (existsSync(summons)) {
	const lines = readFileSync(summons, "utf8").split("\n").filter((l) => l && new Date(l.split(" ")[0]).getTime() >= since);
	const kinds = {};
	for (const l of lines) {
		const m = /kind=(\w+) vessel=(\S+)/.exec(l);
		if (m) kinds[`${m[1]}:${m[2]}`] = (kinds[`${m[1]}:${m[2]}`] ?? 0) + 1;
	}
	P(`summons.log: ${lines.length} dispatches. ${Object.entries(kinds).sort((a, b) => b[1] - a[1]).map(([k, v]) => `${k}=${v}`).join(", ")}`);
} else P(`summons.log not found.`);
P(`Golem spend and verdicts: \`anvil status --all --since <window>\` (anvil >= 0.3.1 records USD per attempt).`);
P();
P(`_Generated by session-audit/scripts/audit.mjs. Catalog: ${catalogPath ? "found" : "NOT FOUND (true cost = pi cost)"}._`);

console.log(out.join("\n"));
if (jsonOut) {
	writeFileSync(jsonOut, JSON.stringify({ since, until, totals: { ...totals }, byDay: Object.fromEntries(Object.entries(byDay).map(([d, v]) => [d, { ...v, sessions: v.sessions.size }])), byModel: Object.fromEntries(Object.entries(byModel).map(([m, v]) => [m, { ...v, sessions: v.sessions.size }])), ctxBuckets, misses, ttl, tools, toolErrCats, editByModel, hardStops, sessions }, null, 1));
	console.error(`json: ${jsonOut}`);
}
