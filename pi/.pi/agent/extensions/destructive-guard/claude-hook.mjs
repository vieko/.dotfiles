#!/usr/bin/env node
/**
 * Claude Code PreToolUse hook for the destructive guard (rules in match.mjs).
 * Prefix deny rules in settings.json miss argument order (`git push origin x
 * --force`); this hook uses the same matcher as the Pi extension.
 *
 *   never    permissionDecision "deny"
 *   confirm  permissionDecision "ask": a prompt even in auto mode
 *
 * Fails open: a parse error or a crash allows the call, so a broken hook
 * cannot stop every session. `PI_DESTRUCTIVE_GUARD=off` turns it off.
 */

import { checkToolCall } from "./match.mjs";

if (process.env.PI_DESTRUCTIVE_GUARD === "off") process.exit(0);

let raw = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (d) => {
	raw += d;
});
process.stdin.on("end", () => {
	try {
		const { tool_name, tool_input } = JSON.parse(raw);
		const hit = checkToolCall(tool_name, tool_input ?? {});
		if (!hit) process.exit(0);
		const never = hit.tier === "never";
		const reason = `destructive-guard (${hit.rule}): ${hit.reason}.${never ? " Never run by an agent here; the user runs it by hand." : ""}`;
		process.stdout.write(
			JSON.stringify({
				hookSpecificOutput: {
					hookEventName: "PreToolUse",
					permissionDecision: never ? "deny" : "ask",
					permissionDecisionReason: reason,
				},
			}),
		);
	} catch {
		// fail open
	}
	process.exit(0);
});
