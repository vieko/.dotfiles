/**
 * habit-nudges
 *
 * Surfaces a built-in pi feature at the moment a habit would have used it.
 * Motivated by the 2026-09-22 session review: 0 uses of `/fork`, `/tree`, or
 * `!` in 30 days, 267 idle resumes, and a steady rate of Escape-aborts, while
 * the features that fix each of those sat unused. A reference card is not
 * enough on its own; the summon-familiar nag and the context-cost expiry
 * prompt showed the nudge-at-decision pattern is what changes behavior.
 *
 * Nudges (each at most once per session, dim notify, never in model context):
 *
 *   shell   Prompt text looks like a shell command -> `!cmd` runs it in the
 *           TUI without a model turn.
 *   abort   Escape while streaming -> Enter steers, Alt+Enter follows up.
 *   fork    Resuming a session with many user turns -> `/fork` restarts from
 *           an earlier prompt and leaves the drift behind.
 *
 * `/cheat` renders ~/.pi/agent/CHEATSHEET.md in an overlay (Esc/Enter/q to
 * close). `/cheat off` mutes nudges for this session.
 */

import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionCommandContext, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { DynamicBorder, getMarkdownTheme } from "@earendil-works/pi-coding-agent";
import { Container, Markdown, matchesKey, ScrollView, Text } from "@earendil-works/pi-tui";

const CHEATSHEET = join(homedir(), ".pi/agent/CHEATSHEET.md");
const FORK_TURNS = 20;

// First tokens that mean "this is a shell command, not a prompt".
const SHELL_HEAD =
	/^(git|gh|ls|cat|pwd|cd|rg|grep|find|pnpm|npm|npx|node|bun|anvil|linear|tmux|vercel|jq|curl|docker|make|cargo|go|python3?|kubectl|stow|brew|which|echo|tail|head|wc)\b/;
// Natural-language tells that override the shell guess.
const PROSE_TELL = /[?]|\b(please|can you|could you|should|why|what|how|the|and then|explain|check if)\b/i;

function looksLikeShell(text: string): boolean {
	const t = text.trim();
	if (!t || t.length > 120 || t.includes("\n")) return false;
	if (t.startsWith("/") || t.startsWith("!")) return false;
	if (!SHELL_HEAD.test(t)) return false;
	return !PROSE_TELL.test(t);
}

function userTurns(ctx: ExtensionContext): number {
	let n = 0;
	for (const e of ctx.sessionManager.getBranch()) {
		if (e.type === "message" && e.message.role === "user") n++;
	}
	return n;
}

export default function (pi: ExtensionAPI) {
	let muted = false;
	const shown = new Set<string>();

	const nudge = (ctx: ExtensionContext, key: string, text: string) => {
		if (muted || !ctx.hasUI || shown.has(key)) return;
		shown.add(key);
		ctx.ui.notify(`tip: ${text} (/cheat for the list)`, "info");
	};

	pi.on("session_start", (event, ctx) => {
		shown.clear();
		if (event.reason !== "resume" && event.reason !== "startup") return;
		const turns = userTurns(ctx);
		if (turns < FORK_TURNS) return;
		nudge(
			ctx,
			"fork",
			`${turns} prompts in this session. /fork picks an earlier prompt and starts a new session from there; the drift after it stays behind`,
		);
	});

	pi.on("input", (event, ctx) => {
		if (event.source !== "interactive" || event.streamingBehavior) return;
		if (!looksLikeShell(event.text)) return;
		nudge(ctx, "shell", `!${event.text.trim().split(/\s+/).slice(0, 2).join(" ")} runs in the TUI without a model turn; !!cmd keeps it out of context`);
	});

	pi.on("agent_end", (event, ctx) => {
		const last = [...event.messages].reverse().find((m) => m.role === "assistant");
		if (!last || last.role !== "assistant" || last.stopReason !== "aborted") return;
		nudge(ctx, "abort", "Enter while streaming queues a steering message for after this turn; Alt+Enter queues a follow-up. Both keep the cache warm");
	});

	pi.registerCommand("cheat", {
		description: "Show the pi cheatsheet (CHEATSHEET.md); `/cheat off|on` mutes or unmutes nudges",
		handler: async (args: string, ctx: ExtensionCommandContext) => {
			const arg = args.trim().toLowerCase();
			if (arg === "off" || arg === "on") {
				muted = arg === "off";
				ctx.ui.notify(`habit nudges ${muted ? "muted for this session" : "on"}`, "info");
				return;
			}
			if (!existsSync(CHEATSHEET)) {
				ctx.ui.notify(`No cheatsheet at ${CHEATSHEET}`, "warning");
				return;
			}
			const md = readFileSync(CHEATSHEET, "utf8");
			if (ctx.mode !== "tui") {
				ctx.ui.notify(md, "info");
				return;
			}
			await ctx.ui.custom<void>(
				(tui, theme, _kb, done) => {
					const container = new Container();
					const border = new DynamicBorder((s: string) => theme.fg("accent", s));
					const scroll = new ScrollView(new Markdown(md, 1, 1, getMarkdownTheme()), { scrollbar: "auto" });
					container.addChild(border);
					container.addChild(scroll);
					container.addChild(new Text(theme.fg("dim", "Up/Down, PgUp/PgDn to scroll. Esc, Enter, or q to close"), 1, 0));
					container.addChild(border);
					return {
						render: (width: number) => container.render(width),
						invalidate: () => container.invalidate(),
						handleInput: (data: string) => {
							if (matchesKey(data, "escape") || matchesKey(data, "enter") || data === "q") return done();
							if (matchesKey(data, "up")) scroll.scrollBy(-1);
							else if (matchesKey(data, "down")) scroll.scrollBy(1);
							else if (matchesKey(data, "pageUp")) scroll.scrollBy(-Math.max(1, scroll.viewportHeight - 2));
							else if (matchesKey(data, "pageDown")) scroll.scrollBy(Math.max(1, scroll.viewportHeight - 2));
							else return;
							tui.requestRender();
						},
					};
				},
				{ overlay: true, overlayOptions: { anchor: "center", width: "80%", maxHeight: "90%" } },
			);
		},
	});
}
