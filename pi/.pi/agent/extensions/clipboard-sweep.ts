/**
 * clipboard-sweep
 *
 * Pi writes every pasted image to `$TMPDIR/pi-clipboard-<uuid>.<ext>` and
 * never deletes it. macOS purges its per-user T dir after ~3 idle days; Linux
 * hosts with a persistent /tmp keep them until reboot.
 *
 * On session_start, unlink pi-clipboard-* files older than MAX_AGE_MS.
 * Start rather than shutdown so crashed / killed sessions are covered on the
 * next launch (same shape as pi-post's sweepRegistry). Recent pastes survive
 * so a paste-quit-resume flow still has its file.
 *
 * Best-effort: any fs error is swallowed.
 */

import { readdirSync, statSync, unlinkSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const PREFIX = "pi-clipboard-";
const MAX_AGE_MS = 3 * 24 * 60 * 60 * 1000;

function sweep(): number {
	const dir = tmpdir();
	let names: string[];
	try {
		names = readdirSync(dir);
	} catch {
		return 0;
	}
	const cutoff = Date.now() - MAX_AGE_MS;
	let removed = 0;
	for (const name of names) {
		if (!name.startsWith(PREFIX)) continue;
		const path = join(dir, name);
		try {
			if (statSync(path).mtimeMs > cutoff) continue;
			unlinkSync(path);
			removed++;
		} catch {
			// already gone or not ours to touch
		}
	}
	return removed;
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async (_event, ctx) => {
		const removed = sweep();
		if (removed > 0 && ctx.hasUI) {
			ctx.ui.notify(`clipboard-sweep: removed ${removed} stale paste${removed === 1 ? "" : "s"}`, "info");
		}
	});
}
