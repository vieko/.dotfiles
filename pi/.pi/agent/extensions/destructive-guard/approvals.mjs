/**
 * Approval inbox for the destructive guard. A session with no UI (a print-mode
 * familiar summoned with `summon-familiar.sh -A`) cannot show the guard's
 * dialog, so the guard writes a request here and holds the tool call until the
 * user answers it: in the Sigil overview, in the macOS alert, or with the
 * `approvals` CLI. Only the user answers; the `approval-self` rule in
 * match.mjs stops an agent from answering its own request. That rule is an
 * accident guard like the rest of match.mjs, not a security boundary.
 *
 * One JSON file per request, `<dir>/<id>.json`, rewritten in place:
 *   { id, status: pending|approved|denied, rule, reason, tool, command, hash,
 *     address, cwd, created, expires, decided?, by? }
 * `hash` covers the full tool input, so an answer applies to that exact call.
 */

import { createHash, randomBytes } from "node:crypto";
import { mkdirSync, readdirSync, readFileSync, renameSync, rmSync, statSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

export const DEFAULT_WAIT_MS = 30 * 60_000;
const KEEP_MS = 7 * 24 * 3_600_000;
const ID = /^[a-z0-9]{12}$/;

export function approvalsDir() {
	return process.env.PI_APPROVALS_DIR || join(homedir(), ".local", "state", "approvals");
}

export const validId = (id) => ID.test(String(id));

export function hashCall(tool, input) {
	return createHash("sha256").update(JSON.stringify([String(tool).toLowerCase(), input ?? {}])).digest("hex");
}

/** What the user reads: the command, or the path a write would touch. */
export function describeCall(input) {
	const i = input ?? {};
	return String(i.command ?? i.path ?? i.file_path ?? JSON.stringify(i));
}

const file = (dir, id) => join(dir, `${id}.json`);

function writeAtomic(path, value) {
	const tmp = `${path}.${process.pid}.tmp`;
	writeFileSync(tmp, `${JSON.stringify(value, null, 2)}\n`, { mode: 0o600 });
	renameSync(tmp, path);
}

export function read(id, dir = approvalsDir()) {
	if (!validId(id)) return null;
	try {
		return JSON.parse(readFileSync(file(dir, id), "utf8"));
	} catch {
		return null;
	}
}

/** Pending requests past their expiry read as expired. */
export function effectiveStatus(req, now = Date.now()) {
	return req.status === "pending" && now > req.expires ? "expired" : req.status;
}

function prune(dir, now) {
	for (const name of readdirSync(dir)) {
		const p = join(dir, name);
		try {
			if (now - statSync(p).mtimeMs > KEEP_MS) rmSync(p);
		} catch {}
	}
}

/**
 * @param {{ tool: string, input: Record<string, unknown>, rule: string, reason: string,
 *   address?: string, cwd?: string, waitMs?: number, now?: number, dir?: string }} o
 */
export function request(o) {
	const dir = o.dir ?? approvalsDir();
	const now = o.now ?? Date.now();
	mkdirSync(dir, { recursive: true, mode: 0o700 });
	prune(dir, now);
	const id = randomBytes(6).toString("hex");
	const req = {
		id,
		status: "pending",
		rule: o.rule,
		reason: o.reason,
		tool: String(o.tool).toLowerCase(),
		command: describeCall(o.input),
		hash: hashCall(o.tool, o.input),
		address: o.address || undefined,
		cwd: o.cwd || undefined,
		created: now,
		expires: now + (o.waitMs ?? DEFAULT_WAIT_MS),
	};
	writeAtomic(file(dir, id), req);
	return req;
}

/**
 * Record the user's answer. Refuses anything but a pending, unexpired request.
 * @returns {{ ok: true, req: object } | { ok: false, code: number, error: string }}
 */
export function decide(id, decision, by = "cli", { dir = approvalsDir(), now = Date.now() } = {}) {
	if (decision !== "approved" && decision !== "denied") return { ok: false, code: 400, error: "decision is approved or denied" };
	const req = read(id, dir);
	if (!req) return { ok: false, code: 404, error: `no approval request ${id}` };
	const status = effectiveStatus(req, now);
	if (status !== "pending") return { ok: false, code: 409, error: `request ${id} is ${status}` };
	const next = { ...req, status: decision, decided: now, by };
	writeAtomic(file(dir, id), next);
	return { ok: true, req: next };
}

/** Requests newest first; `all` adds decided and expired ones from the last day. */
export function list({ dir = approvalsDir(), all = false, now = Date.now() } = {}) {
	let names;
	try {
		names = readdirSync(dir).filter((n) => n.endsWith(".json"));
	} catch {
		return [];
	}
	return names
		.map((n) => read(n.slice(0, -5), dir))
		.filter(Boolean)
		.map((r) => ({ ...r, status: effectiveStatus(r, now) }))
		.filter((r) => r.status === "pending" || (all && now - (r.decided ?? r.created) < 86_400_000))
		.sort((a, b) => b.created - a.created);
}

/**
 * Wait for the answer to a request the caller made. Resolves "approved" only
 * when the stored hash is the hash of the call the caller holds.
 * @returns {Promise<"approved" | "denied" | "expired" | "aborted">}
 */
export function waitFor(id, hash, { dir = approvalsDir(), signal, pollMs = 1000 } = {}) {
	return new Promise((resolve) => {
		let timer;
		const done = (v) => {
			clearInterval(timer);
			signal?.removeEventListener?.("abort", onAbort);
			resolve(v);
		};
		const onAbort = () => done("aborted");
		const tick = () => {
			const req = read(id, dir);
			if (!req) return done("denied");
			const status = effectiveStatus(req);
			if (status === "approved") return done(req.hash === hash ? "approved" : "denied");
			if (status !== "pending") done(status);
		};
		if (signal?.aborted) return resolve("aborted");
		signal?.addEventListener?.("abort", onAbort);
		timer = setInterval(tick, pollMs);
		tick();
	});
}
