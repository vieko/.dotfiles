/**
 * destructive-guard
 *
 * Pi has no permission layer: every tool call runs. This extension adds the
 * deny-rule layer for the commands the "Destructive command guard" in
 * ~/.pi/agent/AGENTS.md names (deploys, publishes, migrations,
 * force-push, credential reads). Rules live in match.mjs, which the Claude
 * Code PreToolUse hook (claude-hook.mjs) also uses.
 *
 *   never    blocked; the user runs it by hand
 *   confirm  a 60 s dialog that defaults to no; blocked outright without a UI
 *            (print mode, RPC), so an unattended familiar never hangs on it
 *
 * Approval inbox (approvals.mjs): with PI_APPROVAL_INBOX=1 (`summon-familiar.sh
 * -A`) a session without a UI holds a `confirm` call instead of blocking it,
 * writes a request the Sigil overview and the `approvals` CLI show, opens a
 * macOS alert, and runs the call only after the user approves it. It waits
 * PI_APPROVAL_WAIT_MS (default 30 min). The flag also makes plain pushes and
 * PR creates and merges ask. Without the flag nothing changes.
 *
 * Nested calls (bash inside codemode) reach tool_call too. It is an accident
 * guard, not a sandbox. `PI_DESTRUCTIVE_GUARD=off` turns it off.
 */

import { spawn } from "node:child_process";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { DEFAULT_WAIT_MS, request, waitFor } from "./approvals.mjs";
import { checkToolCall } from "./match.mjs";

const CONFIRM_MS = 60_000;

function describe(input: Record<string, unknown>): string {
	const s = String(input.command ?? input.path ?? input.file_path ?? "");
	return s.length > 400 ? `${s.slice(0, 400)}…` : s;
}

/** The alert runs detached through the CLI; a missing CLI only loses the alert. */
function alert(id: string) {
	try {
		const child = spawn(`${process.env.HOME}/.scripts/approvals`, ["prompt", id], { detached: true, stdio: "ignore" });
		child.on("error", () => {});
		child.unref();
	} catch {}
}

export default function (pi: ExtensionAPI) {
	if (process.env.PI_DESTRUCTIVE_GUARD === "off") return;
	const inbox = process.env.PI_APPROVAL_INBOX === "1";
	const waitMs = Number(process.env.PI_APPROVAL_WAIT_MS) || DEFAULT_WAIT_MS;

	pi.on("tool_call", async (event, ctx) => {
		const input = (event.input ?? {}) as Record<string, unknown>;
		const hit = checkToolCall(event.toolName, input, { inbox });
		if (!hit) return undefined;

		const tell = (why: string) => ({
			block: true,
			reason: `destructive-guard (${hit.rule}): ${hit.reason}. ${why} Do not retry it another way; ask the user.`,
		});

		if (hit.tier === "never") return tell("This command is never run by an agent here; the user runs it by hand.");

		if (!ctx.hasUI) {
			if (!inbox) return tell("It needs the user's yes, and this session has no UI to ask.");
			const req = request({
				tool: event.toolName,
				input,
				rule: hit.rule,
				reason: hit.reason,
				address: process.env.PI_SESSION_ADDRESS,
				cwd: ctx.cwd,
				waitMs,
			});
			alert(req.id);
			const answer = await waitFor(req.id, req.hash, { signal: ctx.signal });
			if (answer === "approved") return undefined;
			return tell(`Approval request ${req.id} was ${answer}.`);
		}

		const ok = await ctx.ui.confirm(
			`destructive-guard: ${hit.rule}`,
			`${hit.reason}\n\n  ${describe(input)}\n\nRun it? (no in ${CONFIRM_MS / 1000}s)`,
			{ timeout: CONFIRM_MS },
		);
		return ok ? undefined : tell("The user declined or did not answer.");
	});
}
