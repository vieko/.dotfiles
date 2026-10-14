/**
 * reminders
 *
 * `/reminders` for the launchd reminders that ~/.scripts/remind-at.sh
 * schedules for pi sessions. The script owns all reminder logic; this only
 * calls it. Bare `/reminders` picks a reminder, then an action;
 * `/reminders list|show|resume|done|cancel [slug]` runs one directly.
 *
 * The footer shows `remind:N!` (warning) when an alert was answered
 * Later or timed out, because an open reminder is easy to forget once its
 * alert is gone; otherwise `remind:N` while some are pending. It refreshes on
 * session start, after each run (the agent schedules reminders through
 * bash), after each command, and every minute (a pending reminder turns
 * open when it fires). macOS only, like the script.
 */

import { execFile } from "node:child_process";
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const SCRIPT = join(homedir(), ".scripts", "remind-at.sh");
const STATE_DIR = join(homedir(), ".local", "state", "reminders");
const REGISTRY = join(homedir(), ".pi", "agent", "post", "registry");
const STATUS_KEY = "reminders";
const ACTIONS = ["list", "show", "resume", "done", "cancel"];

interface Reminder {
	slug: string;
	status: string;
	due: number;
	target: string;
	title: string;
	ask: string;
}

// Resume waits up to ~20s for pi to register, so allow well over that.
function run(args: string[]): Promise<{ ok: boolean; out: string }> {
	return new Promise((resolve) => {
		execFile(SCRIPT, args, { timeout: 60_000 }, (err, stdout, stderr) => {
			resolve({ ok: !err, out: `${stdout}${stderr}`.trim() });
		});
	});
}

async function listReminders(): Promise<Reminder[] | undefined> {
	const { ok, out } = await run(["--list", "--tsv"]);
	if (!ok) return undefined;
	return out
		.split("\n")
		.filter(Boolean)
		.map((line) => {
			const [slug, status, due, target, title, ask] = line.split("\t");
			return { slug, status, due: Number(due), target, title, ask };
		});
}

function sessionName(address: string): string {
	try {
		return JSON.parse(readFileSync(join(REGISTRY, `${address}.json`), "utf8")).name ?? address;
	} catch {
		return address;
	}
}

function formatDue(epoch: number): string {
	return new Date(epoch * 1000).toLocaleString("en-CA", {
		weekday: "short",
		month: "short",
		day: "numeric",
		hour: "2-digit",
		minute: "2-digit",
		hour12: false,
	});
}

function describe(r: Reminder): string {
	let brief = "";
	try {
		brief = readFileSync(join(STATE_DIR, `${r.slug}.txt`), "utf8").trim();
	} catch {
		brief = "(no brief on disk)";
	}
	return [
		`${r.title} [${r.status}, due ${formatDue(r.due)}]`,
		`Ask: ${r.ask}`,
		`Session: ${sessionName(r.target)} (${r.target})`,
		"",
		brief,
	].join("\n");
}

export default function (pi: ExtensionAPI) {
	if (process.platform !== "darwin") return;

	let cached: Reminder[] = [];
	let timer: ReturnType<typeof setInterval> | undefined;
	let current: ExtensionContext | undefined;

	async function refresh(ctx: ExtensionContext | undefined): Promise<void> {
		if (!ctx?.hasUI) return;
		const list = await listReminders();
		if (list) cached = list;
		const open = cached.filter((r) => r.status === "open").length;
		const pending = cached.length - open;
		const theme = ctx.ui.theme;
		// Shared footer format (docs/agent-packages.md): fired reminders need action.
		const text = open
			? theme.fg("warning", `remind:${open}!`)
			: pending
				? theme.fg("dim", `remind:${pending}`)
				: undefined;
		try {
			ctx.ui.setStatus(STATUS_KEY, text);
		} catch {
			// The context went stale (session replaced); the next event refreshes.
		}
	}

	async function act(action: string, slug: string | undefined, ctx: ExtensionContext): Promise<void> {
		if (action === "list") {
			const { out } = await run(["--list"]);
			ctx.ui.notify(out || "no pending or open reminders", "info");
			return;
		}
		if (!slug) {
			ctx.ui.notify(`usage: /reminders ${action} <slug>`, "error");
			return;
		}
		if (action === "show") {
			const r = (await listReminders())?.find((x) => x.slug === slug);
			ctx.ui.notify(r ? describe(r) : `no reminder named ${slug}`, r ? "info" : "error");
			return;
		}
		if (action === "cancel" && ctx.hasUI) {
			const sure = await ctx.ui.confirm("Cancel reminder?", `${slug} and its brief are deleted.`);
			if (!sure) return;
		}
		if (action === "resume") ctx.ui.notify(`Opening the session for ${slug}...`, "info");
		const { ok, out } = await run([`--${action}`, slug]);
		ctx.ui.notify(out || `${action} ${slug}: done`, ok ? "info" : "error");
	}

	async function pick(ctx: ExtensionContext): Promise<void> {
		const list = await listReminders();
		if (!list?.length) {
			ctx.ui.notify(list ? "no pending or open reminders" : `could not run ${SCRIPT}`, list ? "info" : "error");
			return;
		}
		const labels = list.map((r) => `${r.slug}  [${r.status}, ${formatDue(r.due)}]  ${r.title}`);
		const chosen = await ctx.ui.select("Reminders", labels);
		const r = chosen ? list[labels.indexOf(chosen)] : undefined;
		if (!r) return;
		const choices = ["Show brief", "Resume session", "Done (close)", "Cancel (delete)"];
		const action = await ctx.ui.select(`${r.slug}: ${r.ask}`, choices);
		const map: Record<string, string> = {
			"Show brief": "show",
			"Resume session": "resume",
			"Done (close)": "done",
			"Cancel (delete)": "cancel",
		};
		if (action) await act(map[action], r.slug, ctx);
	}

	pi.registerCommand("reminders", {
		description: "List remind-at.sh reminders; show, resume, close, or cancel one",
		getArgumentCompletions: async (prefix) => {
			const [action, slug = ""] = prefix.split(/\s+/);
			if (!prefix.includes(" ")) {
				const items = ACTIONS.filter((a) => a.startsWith(action));
				return items.length ? items.map((a) => ({ value: a, label: a })) : null;
			}
			if (action === "list") return null;
			const items = ((await listReminders()) ?? cached).filter((r) => r.slug.startsWith(slug));
			return items.length
				? items.map((r) => ({ value: `${action} ${r.slug}`, label: r.slug, description: `${r.status}: ${r.title}` }))
				: null;
		},
		handler: async (args, ctx) => {
			const [action, slug] = args.trim().split(/\s+/).filter(Boolean);
			if (!action) {
				if (ctx.hasUI) await pick(ctx);
				else await act("list", undefined, ctx);
			} else if (ACTIONS.includes(action)) {
				await act(action, slug, ctx);
			} else {
				ctx.ui.notify(`usage: /reminders [${ACTIONS.join("|")}] [slug]`, "error");
			}
			await refresh(ctx);
		},
	});

	pi.on("session_start", async (_event, ctx) => {
		current = ctx;
		await refresh(ctx);
		if (!timer && ctx.hasUI) {
			timer = setInterval(() => void refresh(current), 60_000);
			timer.unref?.();
		}
	});

	pi.on("agent_settled", async (_event, ctx) => {
		current = ctx;
		await refresh(ctx);
	});

	pi.on("session_shutdown", () => {
		if (timer) clearInterval(timer);
		timer = undefined;
		current = undefined;
	});
}
