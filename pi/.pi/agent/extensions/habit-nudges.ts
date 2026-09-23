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
import { getMarkdownTheme } from "@earendil-works/pi-coding-agent";
import { Markdown, matchesKey, truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

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
					// Full rounded frame, like pi's own overlays; top/bottom-only borders are
					// the in-transcript idiom and bleed into the chat behind a floating box.
					const body = new Markdown(md, 1, 0, getMarkdownTheme());
					const border = (s: string) => theme.fg("border", s);
					let top = 0;
					let viewport = 1;
					const scroll = (delta: number) => {
						top = Math.max(0, top + delta);
						tui.requestRender();
					};
					return {
						render: (width: number) => {
							const innerW = Math.max(1, width - 2);
							const lines = body.render(innerW);
							// Frame = title row + footer row + 2 border rows. Cap to the terminal.
							viewport = Math.max(3, Math.floor(tui.terminal.rows * 0.9) - 4);
							const maxTop = Math.max(0, lines.length - viewport);
							if (top > maxTop) top = maxTop;
							const slice = lines.slice(top, top + viewport);
							const pos = lines.length > viewport ? ` ${top + 1}-${top + slice.length}/${lines.length} ` : "";

							const title = truncateToWidth(" pi cheatsheet ", innerW);
							const tw = visibleWidth(title);
							const left = "─".repeat(Math.floor((innerW - tw) / 2));
							const right = "─".repeat(Math.max(0, innerW - tw - left.length));
							const out: string[] = [border(`╭${left}`) + theme.fg("accent", title) + border(`${right}╮`)];
							for (const line of slice) out.push(border("│") + truncateToWidth(line, innerW, "…", true) + border("│"));
							const hint = theme.fg("dim", ` ↑↓ PgUp PgDn scroll · Esc Enter q close${pos ? " ·" + pos : ""}`);
							out.push(border("│") + truncateToWidth(hint, innerW, "…", true) + border("│"));
							out.push(border(`╰${"─".repeat(innerW)}╯`));
							return out;
						},
						invalidate: () => body.invalidate(),
						handleInput: (data: string) => {
							if (matchesKey(data, "escape") || matchesKey(data, "enter") || data === "q") return done();
							if (matchesKey(data, "up") || data === "k") scroll(-1);
							else if (matchesKey(data, "down") || data === "j") scroll(1);
							else if (matchesKey(data, "pageUp")) scroll(-(viewport - 1));
							else if (matchesKey(data, "pageDown") || data === " ") scroll(viewport - 1);
							else if (matchesKey(data, "home") || data === "g") scroll(-top);
							else if (matchesKey(data, "end") || data === "G") scroll(Number.MAX_SAFE_INTEGER / 2);
						},
					};
				},
				{ overlay: true, overlayOptions: { anchor: "center", width: "80%", maxHeight: "90%" } },
			);
		},
	});
}
