/**
 * destructive-guard
 *
 * Pi has no permission layer: every tool call runs. This extension adds the
 * deny-rule layer for the commands the "Destructive command guard" in
 * ~/.pi/agent/AGENTS.md names (env pull, deploys, publishes, migrations,
 * force-push, credential reads). Rules live in match.mjs, which the Claude
 * Code PreToolUse hook (claude-hook.mjs) also uses.
 *
 *   never    blocked; the user runs it by hand
 *   confirm  a 60 s dialog that defaults to no; blocked outright without a UI
 *            (print mode, RPC), so an unattended familiar never hangs on it
 *
 * Nested calls (bash inside codemode) reach tool_call too. It is an accident
 * guard, not a sandbox. `PI_DESTRUCTIVE_GUARD=off` turns it off.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { checkToolCall } from "./match.mjs";

const CONFIRM_MS = 60_000;

function describe(input: Record<string, unknown>): string {
	const s = String(input.command ?? input.path ?? input.file_path ?? "");
	return s.length > 400 ? `${s.slice(0, 400)}…` : s;
}

export default function (pi: ExtensionAPI) {
	if (process.env.PI_DESTRUCTIVE_GUARD === "off") return;

	pi.on("tool_call", async (event, ctx) => {
		const input = (event.input ?? {}) as Record<string, unknown>;
		const hit = checkToolCall(event.toolName, input);
		if (!hit) return undefined;

		const tell = (why: string) => ({
			block: true,
			reason: `destructive-guard (${hit.rule}): ${hit.reason}. ${why} Do not retry it another way; ask the user.`,
		});

		if (hit.tier === "never") return tell("This command is never run by an agent here; the user runs it by hand.");
		if (!ctx.hasUI) return tell("It needs the user's yes, and this session has no UI to ask.");

		const ok = await ctx.ui.confirm(
			`destructive-guard: ${hit.rule}`,
			`${hit.reason}\n\n  ${describe(input)}\n\nRun it? (no in ${CONFIRM_MS / 1000}s)`,
			{ timeout: CONFIRM_MS },
		);
		return ok ? undefined : tell("The user declined or did not answer.");
	});
}
