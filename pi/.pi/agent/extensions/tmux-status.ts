/**
 * tmux-status
 *
 * Marks the tmux window Pi is running in with its agent state so the
 * status bar shows what needs attention without a sound or a glance at
 * the pane. Sets the window user option `@pi_status` to `working` on
 * agent_start, `done` on agent_settled, and clears it on shutdown; the
 * tmux `window-status-format` renders the marker (see tmux.conf).
 *
 * `done` clears on the next prompt. Focus-clear is handled tmux-side via
 * a `pane-focus-in` hook. No-ops outside tmux.
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

	pi.on("agent_start", () => setStatus("working"));
	pi.on("agent_settled", () => setStatus("done"));
	pi.on("session_shutdown", () => setStatus(""));
}
