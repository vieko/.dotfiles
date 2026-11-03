/**
 * restart
 *
 * `/restart` ends this pi process and resumes the same session in a fresh
 * one, so a session picks up a `pi update` without the manual
 * /exit + `pi -c` (or `pi -r` in a directory with many sessions). `/reload`
 * is not enough: it reloads extensions and settings, but the pi core stays
 * the release this process started on. Week 44 had a Summoner run 19 days
 * on a pi older than a fix it kept hitting; the habit-nudges `stale` nudge
 * points here.
 *
 * pi has no re-exec (the launcher `exec`s the release once), so this
 * needs the terminal: a detached watcher waits for this pid to exit, then
 * types `cd <cwd> && pi --session <file>` into this pane through
 * construct-term.sh (tmux pane or Rex block). The session restores its
 * model and thinking level. Env a summon set inline on the pi command
 * (PI_COUNSEL, SIGIL_ROLE, SIGIL_ROOM) is carried over, since the pane's
 * shell never had it. Outside tmux or Rex it prints the command instead.
 *
 * Upstream request for launcher support: earendil-works/pi#11748.
 *
 * The prompt cache does not survive a restart; `/compact` first makes the
 * one rewrite cheaper.
 */

import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";

const CONSTRUCT_TERM = join(homedir(), ".scripts/construct-term.sh");
// Set inline by summon-familiar.sh on the pi command, not in the pane's shell.
const CARRIED_ENV = ["PI_COUNSEL", "SIGIL_ROLE", "SIGIL_ROOM"];
// How long the watcher waits for this process to exit before it gives up.
const EXIT_WAIT_S = 60;

const q = (s: string) => `'${s.replaceAll("'", `'\\''`)}'`;

// construct-term.sh id of the pane this process runs in; tmux wins inside both.
function paneId(): string | undefined {
	const env = process.env;
	if (env.TMUX && env.TMUX_PANE) return env.TMUX_PANE;
	if (env.REX_SESSION && env.REX_BLOCK) return `rex/${env.REX_SESSION}/${env.REX_BLOCK}`;
	return undefined;
}

function resumeCommand(cwd: string, sessionFile: string): string {
	const env = CARRIED_ENV.filter((k) => process.env[k]).map((k) => `${k}=${q(process.env[k] as string)}`);
	return `cd ${q(cwd)} && ${env.length ? `env ${env.join(" ")} ` : ""}pi --session ${q(sessionFile)}`;
}

// Waits for `pid` to exit, then types the command into the pane. Detached and
// in its own session, so this process's exit does not take it down.
const WATCHER = `
pid=$1 pane=$2 term=$3 n=$(( $4 * 10 ))
while kill -0 "$pid" 2>/dev/null; do
  n=$((n - 1)); [ "$n" -gt 0 ] || exit 1
  sleep 0.1
done
sleep 0.5
printf '%s' "$PI_RESTART_CMD" | "$term" send "$pane"
`;

export default function (pi: ExtensionAPI) {
	pi.registerCommand("restart", {
		description: "End this pi process and resume this session in a new one (picks up a pi update)",
		handler: async (_args: string, ctx: ExtensionCommandContext) => {
			const sessionFile = ctx.sessionManager.getSessionFile();
			// A session file is written only once the session has a message.
			if (!sessionFile || !existsSync(sessionFile)) {
				ctx.ui.notify("restart: this session is not saved to a file, so there is nothing to resume", "warning");
				return;
			}
			if (!ctx.isIdle()) {
				ctx.ui.notify("restart: wait for the current run to finish, then /restart", "warning");
				return;
			}
			const cmd = resumeCommand(ctx.sessionManager.getCwd(), sessionFile);
			const pane = paneId();
			if (!pane || !existsSync(CONSTRUCT_TERM)) {
				ctx.ui.notify(`restart: not in tmux or Rex. /exit, then run:\n${cmd}`, "info");
				return;
			}
			const child = spawn("sh", ["-c", WATCHER, "restart", String(process.pid), pane, CONSTRUCT_TERM, String(EXIT_WAIT_S)], {
				detached: true,
				stdio: "ignore",
				env: { ...process.env, PI_RESTART_CMD: cmd },
			});
			child.unref();
			ctx.ui.notify("restart: resuming this session in a new pi process", "info");
			ctx.shutdown();
		},
	});
}
