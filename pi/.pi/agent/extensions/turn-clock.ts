/**
 * turn-clock
 *
 * Prints a dim "done 15:30 · 13s" line in the chat when a run ends,
 * like Claude Code's "Baked for 13s · done 3:30 p.m.". A pane you come
 * back to shows when it finished and if the prompt cache is likely cold.
 *
 * The clock starts on the first agent_start after the last settle, so
 * retries and queued messages count toward one run. It stops on
 * agent_settled, which fires once per run. Aborted runs print nothing
 * (Esc is you, not news); a run that ended on a model error prints
 * "error" instead of "done". Times are Mountain Time, 24-hour.
 *
 * Interactive mode only. Uses ctx.ui.notify, so the line is not saved to
 * the session; the session JSONL already timestamps every entry.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const clock = new Intl.DateTimeFormat("en-GB", {
	timeZone: "America/Edmonton",
	hour: "2-digit",
	minute: "2-digit",
	hourCycle: "h23",
});

function formatDuration(ms: number): string {
	const s = Math.round(ms / 1000);
	if (s < 60) return `${s}s`;
	const m = Math.floor(s / 60);
	if (m < 60) return `${m}m ${s % 60}s`;
	return `${Math.floor(m / 60)}h ${m % 60}m`;
}

export default function (pi: ExtensionAPI) {
	let startedAt: number | null = null;
	let lastRunErrored = false;

	pi.on("agent_start", () => {
		startedAt ??= Date.now();
		lastRunErrored = false;
	});

	pi.on("agent_end", (event) => {
		const last = [...event.messages].reverse().find((m) => m.role === "assistant");
		lastRunErrored = last?.role === "assistant" && last.stopReason === "error";
	});

	pi.on("agent_settled", (event, ctx) => {
		const start = startedAt;
		startedAt = null;
		if (event.aborted || start === null || ctx.mode !== "tui") return;
		const now = Date.now();
		const label = lastRunErrored ? "error" : "done";
		ctx.ui.notify(`${label} ${clock.format(now)} · ${formatDuration(now - start)}`, "info");
	});
}
