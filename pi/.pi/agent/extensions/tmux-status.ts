/**
 * tmux-status
 *
 * Marks the tmux window Pi is running in with its agent state so the
 * status bar shows what needs attention without a sound or a glance at
 * the pane. Sets the window user option `@pi_status` to `working` on
 * agent_start, `done` or `error` on agent_settled (error when the last
 * run's assistant message stopped with `stopReason: "error"`), `done`
 * while a blocking extension UI prompt waits on input, and clears it on
 * shutdown; the tmux `window-status-format` renders the marker (see
 * tmux.conf).
 *
 * `done`/`error` clear on the next prompt. Focus-clear is handled
 * tmux-side via a `pane-focus-in` hook. No-ops outside tmux.
 */

import { execFile } from "node:child_process";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const pane = process.env.TMUX_PANE;

function setStatus(value: string): void {
	if (!pane) return;
	try {
		const child = execFile("tmux", ["set-option", "-w", "-t", pane, "@pi_status", value], () => {
			// Ignore failures (server gone, pane closed) — never disturb the session.
		});
		child.on("error", () => {});
	} catch {
		// tmux binary missing — silently no-op.
	}
}

export default function (pi: ExtensionAPI) {
	if (!pane) return;

	let lastRunErrored = false;
	let running = false;

	pi.on("agent_start", () => {
		lastRunErrored = false;
		running = true;
		setStatus("working");
	});

	pi.on("agent_end", (event) => {
		// Pi may auto-retry after this; agent_settled decides what to show.
		const last = [...event.messages].reverse().find((m) => m.role === "assistant");
		lastRunErrored = last?.role === "assistant" && last.stopReason === "error";
	});

	pi.on("agent_settled", () => {
		running = false;
		setStatus(lastRunErrored ? "error" : "done");
	});

	// Blocking ctx.ui prompts (confirm/select/input/editor) need you even
	// though the run hasn't ended. Prompts opened while idle (slash
	// commands) clear rather than fall back to `working`.
	pi.on("ui_prompt_start", () => setStatus("done"));
	pi.on("ui_prompt_end", () => setStatus(running ? "working" : ""));

	pi.on("session_shutdown", () => setStatus(""));
}
