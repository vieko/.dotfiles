/**
 * sound-on-end
 *
 * Plays a random sound from ~/.agents/sounds/ when the agent finishes
 * responding to a user prompt. Mirrors the Claude Code Stop hook.
 *
 * The shared `play-random.sh` script is OS-aware (afplay on macOS,
 * mpg123 on Linux) and exits silently if no player is available, so this
 * extension is safe on any host without further branching.
 */

import { spawn } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const script = join(homedir(), ".agents", "sounds", "play-random.sh");
const category = "yes"; // acknowledgment sounds — match the "agent done" semantic

export default function (pi: ExtensionAPI) {
	pi.on("agent_end", () => {
		try {
			const child = spawn(script, [category], {
				detached: true,
				stdio: "ignore",
			});
			child.on("error", () => {
				// Script missing or not executable — silently no-op.
			});
			child.unref();
		} catch {
			// Never let audio failures interfere with the session.
		}
	});
}
