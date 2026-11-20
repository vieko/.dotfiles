/**
 * tab-title
 *
 * Gives each Pi tab a title that tells sessions apart. Pi's own title is
 * `π - <folder>`, so a dozen sessions in one repo all read `π - gtm` in
 * Rex's sidebar (and in any terminal tab bar).
 *
 * Two parts:
 * - Auto-name: an unnamed session gets a name from its first prompt: the
 *   first issue key (`gtmeng-5068`), else a non-default git branch, else a
 *   2-4 word slug of the prompt (a one-word slug waits for the next
 *   prompt). The name is the pi session name, so
 *   `/resume` and pi-post show it too. `/name`, `--name` and existing
 *   names always win. A name another live pi-post session already uses
 *   gets a `-2`, `-3` suffix.
 * - Title: `<name> · <folder>` without the `π - ` prefix (the Rex icon
 *   shows it is pi); the folder is left out when the name already has it.
 *
 * Pi rewrites the title on session_info_changed and after binding
 * extensions, so the title is reapplied shortly after those points.
 * `PI_TAB_TITLE=off` turns the extension off.
 */

import { execFileSync } from "node:child_process";
import { readdirSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { basename, join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const ISSUE_KEY = /\b([a-z][a-z0-9]{1,9}-\d{2,6})\b/i;
const NOT_ISSUES = new Set(["utf", "sha", "iso", "rfc", "base", "x", "gpt", "claude", "gemini"]);
const DEFAULT_BRANCHES = new Set(["main", "master", "HEAD", "trunk", "develop"]);
const STOPWORDS = new Set(
	(
		"a an the and or but if then so to of in on at by for with from into onto about as is are was were be been " +
		"it its this that these those there here we us our you your i me my he she they them their can could " +
		"should would will shall may might must do does did done have has had how what why when where which who " +
		"please pls let lets let's just also some any all more most very really see look make get go use using " +
		"need want like think know hey hi ok okay yes no not now up out over between than too"
	).split(" "),
);
const MAX_WORDS = 4;
const MAX_SLUG = 32;

function issueKey(text: string): string | undefined {
	const re = new RegExp(ISSUE_KEY, "gi");
	for (const m of text.matchAll(re)) {
		const prefix = m[1].split("-")[0].toLowerCase();
		if (!NOT_ISSUES.has(prefix)) return m[1].toLowerCase();
	}
	return undefined;
}

function gitBranch(cwd: string): string | undefined {
	try {
		const branch = execFileSync("git", ["rev-parse", "--abbrev-ref", "HEAD"], {
			cwd,
			timeout: 1000,
			stdio: ["ignore", "pipe", "ignore"],
		})
			.toString()
			.trim();
		if (!branch || DEFAULT_BRANCHES.has(branch)) return undefined;
		return branch.split("/").pop() || undefined;
	} catch {
		return undefined;
	}
}

function slug(text: string): string | undefined {
	let body = text.trim();
	// `/skill:name args` or `/template args`: name from the args, else the command.
	const cmd = body.match(/^\/(?:skill:)?([\w.-]+)\s*/);
	if (cmd) body = body.slice(cmd[0].length) || cmd[1];
	const words = body
		.replace(/https?:\/\/\S+/g, " ")
		.replace(/(?:^|\s)[~.]?\/\S+/g, " ")
		.toLowerCase()
		.replace(/[^a-z0-9\s-]/g, " ")
		.split(/\s+/)
		.filter((w) => w.length > 1 && !STOPWORDS.has(w));
	const picked: string[] = [];
	for (const w of words) {
		if (picked.length >= MAX_WORDS || [...picked, w].join("-").length > MAX_SLUG) break;
		picked.push(w);
	}
	// One word ("continue", "wrap") names nothing; wait for a better prompt.
	return picked.length > 1 ? picked.join("-") : undefined;
}

export function deriveName(prompt: string, cwd: string): string | undefined {
	return issueKey(prompt) ?? gitBranch(cwd) ?? slug(prompt);
}

/** Names held by other live pi-post sessions; empty when pi-post is absent. */
function takenNames(selfSessionId: string | undefined): Set<string> {
	const dir = join(process.env.PI_POST_DIR || join(homedir(), ".pi", "agent", "post"), "registry");
	const taken = new Set<string>();
	try {
		for (const file of readdirSync(dir)) {
			if (!file.endsWith(".json")) continue;
			try {
				const r = JSON.parse(readFileSync(join(dir, file), "utf8"));
				if (r.sessionId === selfSessionId || typeof r.name !== "string") continue;
				// pi-post drops pid at shutdown; a dead pid throws.
				if (typeof r.pid !== "number") continue;
				process.kill(r.pid, 0);
				taken.add(r.name);
			} catch {
				// unreadable record or dead process
			}
		}
	} catch {
		// no registry
	}
	return taken;
}

function unique(name: string, sessionId: string | undefined): string {
	const taken = takenNames(sessionId);
	if (!taken.has(name)) return name;
	for (let n = 2; ; n++) if (!taken.has(`${name}-${n}`)) return `${name}-${n}`;
}

function firstUserText(ctx: ExtensionContext): string | undefined {
	for (const e of ctx.sessionManager.getBranch()) {
		if (e.type !== "message" || e.message.role !== "user") continue;
		const c = e.message.content;
		const text = typeof c === "string" ? c : c.map((p) => (p.type === "text" ? p.text : "")).join(" ");
		if (text.trim()) return text;
	}
	return undefined;
}

export function titleFor(name: string | undefined, cwd: string): string {
	const folder = basename(cwd);
	if (!name) return folder;
	return name === folder || name.startsWith(`${folder}-`) ? name : `${name} · ${folder}`;
}

export default function (pi: ExtensionAPI) {
	if (process.env.PI_TAB_TITLE === "off") return;

	let timers: NodeJS.Timeout[] = [];

	function applyTitle(ctx: ExtensionContext): void {
		if (!ctx.hasUI) return;
		for (const t of timers) clearTimeout(t);
		const set = () => ctx.ui.setTitle(titleFor(pi.getSessionName(), ctx.cwd));
		set();
		timers = [100, 1000].map((ms) => {
			const t = setTimeout(set, ms);
			t.unref?.();
			return t;
		});
	}

	function maybeName(prompt: string | undefined, ctx: ExtensionContext): void {
		if (!ctx.hasUI || pi.getSessionName() || !prompt) return;
		const name = deriveName(prompt, ctx.cwd);
		if (name) pi.setSessionName(unique(name, ctx.sessionManager.getSessionId()));
	}

	pi.on("session_start", async (_event, ctx) => {
		// Resumed or reloaded unnamed sessions get a name from their first prompt.
		maybeName(firstUserText(ctx), ctx);
		applyTitle(ctx);
	});

	pi.on("input", async (event, ctx) => {
		if (event.source !== "extension") maybeName(event.text, ctx);
		return { action: "continue" };
	});

	pi.on("session_info_changed", async (_event, ctx) => {
		applyTitle(ctx);
	});

	pi.on("session_shutdown", async () => {
		for (const t of timers) clearTimeout(t);
		timers = [];
	});
}
