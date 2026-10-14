/**
 * waits
 *
 * Footer item for detached waiters that will message this session:
 * `pr-wait.sh --detach --notify` and `deploy-wait.sh --detach --notify` in
 * ~/dev/gtm. Each waiter writes a record to
 * $TMPDIR/agent-waits/<session address>/ and deletes it after its pi-post
 * message is delivered (scripts/lib/agent-notify.sh). So a record whose pid
 * is gone means the waiter died or failed to report, and the session would
 * otherwise wait for a message that never comes.
 *
 * Footer, in the shared format (docs/agent-packages.md): `wait:#3146` or
 * `wait:2` in dim while waiters run; `wait:#3146!` in warning when one died
 * without reporting. `/waits` lists records with their logs; `/waits clear`
 * deletes dead ones. Refreshes on session start, after each tool call, and
 * every 15s.
 */

import { readdirSync, readFileSync, unlinkSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const STATUS_KEY = "waits";
// A live pid older than this is treated as reused; the default waits time out after 30 min.
const MAX_AGE_S = 24 * 3600;
// Dead records nobody cleared are dropped silently after a week.
const DROP_AGE_S = 7 * 24 * 3600;

interface WaitRecord {
	file: string;
	kind: string;
	target: string;
	pid: number;
	log: string;
	started: number;
	alive: boolean;
}

// Same sanitising as agent-notify.sh, so the address maps to the same directory.
const safe = (s: string) => s.replace(/[^A-Za-z0-9._-]/g, "_");

function recordDir(): string | undefined {
	const address = process.env.PI_SESSION_ADDRESS;
	return address ? join(tmpdir(), "agent-waits", safe(address)) : undefined;
}

function alive(pid: number): boolean {
	try {
		process.kill(pid, 0);
		return true;
	} catch (err) {
		return (err as NodeJS.ErrnoException).code === "EPERM";
	}
}

function readRecords(): WaitRecord[] {
	const dir = recordDir();
	if (!dir) return [];
	let names: string[];
	try {
		names = readdirSync(dir).filter((n) => n.endsWith(".json"));
	} catch {
		return [];
	}
	const now = Date.now() / 1000;
	const out: WaitRecord[] = [];
	for (const name of names) {
		const file = join(dir, name);
		try {
			const r = JSON.parse(readFileSync(file, "utf8"));
			const age = now - (r.started ?? 0);
			const live = typeof r.pid === "number" && age < MAX_AGE_S && alive(r.pid);
			if (!live && age > DROP_AGE_S) {
				unlinkSync(file);
				continue;
			}
			out.push({ file, kind: r.kind ?? "?", target: String(r.target ?? "?"), pid: r.pid, log: r.log ?? "", started: r.started ?? 0, alive: live });
		} catch {
			// Half-written or foreign file; the writer renames into place, so skip it.
		}
	}
	return out.sort((a, b) => a.started - b.started);
}

/** `#3146` for a PR number or URL; `deploy#3146` / `deploy@main` / `deploy@1a2b3c4d5` for deploy-wait. One token, no spaces. */
function label(r: WaitRecord): string {
	const pr = /^\d+$/.test(r.target) ? r.target : /\/pull\/(\d+)/.exec(r.target)?.[1];
	const what = pr ? `#${pr}` : /^[0-9a-f]{10,}$/.test(r.target) ? r.target.slice(0, 9) : r.target.replace(/\s+/g, "-");
	const kind = r.kind.replace(/-wait$/, "");
	return r.kind === "pr-wait" ? what : `${kind}${pr ? "" : "@"}${what}`;
}

function age(started: number): string {
	const m = Math.max(0, Math.round((Date.now() / 1000 - started) / 60));
	return m < 60 ? `${m}m` : `${Math.floor(m / 60)}h${m % 60 ? `${m % 60}m` : ""}`;
}

export default function (pi: ExtensionAPI) {
	let timer: ReturnType<typeof setInterval> | undefined;
	let current: ExtensionContext | undefined;

	function refresh(ctx: ExtensionContext | undefined): void {
		if (!ctx?.hasUI) return;
		const records = readRecords();
		const dead = records.filter((r) => !r.alive);
		const live = records.filter((r) => r.alive);
		const theme = ctx.ui.theme;
		const text = dead.length
			? theme.fg("warning", `wait:${dead.length === 1 ? label(dead[0]) : dead.length}!`)
			: live.length
				? theme.fg("dim", `wait:${live.length === 1 ? label(live[0]) : live.length}`)
				: undefined;
		try {
			ctx.ui.setStatus(STATUS_KEY, text);
		} catch {
			// The context went stale (session replaced); the next event refreshes.
		}
	}

	pi.registerCommand("waits", {
		description: "List detached pr-wait/deploy-wait waiters for this session; `clear` deletes dead ones",
		getArgumentCompletions: async (prefix) => ("clear".startsWith(prefix) ? [{ value: "clear", label: "clear" }] : null),
		handler: async (args, ctx) => {
			const records = readRecords();
			if (args.trim() === "clear") {
				const dead = records.filter((r) => !r.alive);
				for (const r of dead) {
					try {
						unlinkSync(r.file);
					} catch {
						// Already gone.
					}
				}
				ctx.ui.notify(dead.length ? `cleared ${dead.length} dead waiter${dead.length === 1 ? "" : "s"}` : "no dead waiters", "info");
			} else if (!records.length) {
				ctx.ui.notify(recordDir() ? "no waiters for this session" : "no session address (pi-post not loaded)", "info");
			} else {
				const lines = records.map(
					(r) => `${r.alive ? "running" : "DEAD   "} ${label(r)}  ${age(r.started)}  pid ${r.pid}  ${r.log}`,
				);
				const hint = records.some((r) => !r.alive) ? "\nDEAD: exited without a delivered message; read its log, then /waits clear." : "";
				ctx.ui.notify(lines.join("\n") + hint, records.some((r) => !r.alive) ? "warning" : "info");
			}
			refresh(ctx);
		},
	});

	pi.on("session_start", async (_event, ctx) => {
		current = ctx;
		refresh(ctx);
		if (!timer && ctx.hasUI) {
			timer = setInterval(() => refresh(current), 15_000);
			timer.unref?.();
		}
	});

	// A waiter is usually started from bash, so show it as soon as the call returns.
	pi.on("tool_execution_end", async (_event, ctx) => {
		current = ctx;
		refresh(ctx);
	});

	pi.on("agent_settled", async (_event, ctx) => {
		current = ctx;
		refresh(ctx);
	});

	pi.on("session_shutdown", () => {
		if (timer) clearInterval(timer);
		timer = undefined;
		current = undefined;
	});
}
