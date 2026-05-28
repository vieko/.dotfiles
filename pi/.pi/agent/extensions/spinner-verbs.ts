/**
 * spinner-verbs
 *
 * Replaces pi's default streaming working indicator with a rotating
 * occult/metallurgical verb plus an animated braille spinner. A fresh verb
 * is picked at session start and again at the start of each LLM turn, so
 * the label changes naturally as the agent works.
 *
 * Source of truth: ~/.agents/verbs.json (canonical: ~/.dotfiles/agents/.agents/verbs.json).
 * Shared with forge (src/display.ts AGENT_VERBS) and Claude Code
 * (settings.json spinnerVerbs.verbs) via sync-verbs.mjs.
 *
 * No-ops silently if verbs.json is missing or malformed.
 */

import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const VERBS_PATH = join(homedir(), ".agents", "verbs.json");
const SPINNER_FRAMES = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];

interface VerbsFile {
	sections: { name: string; verbs: string[] }[];
}

function loadVerbs(): string[] {
	try {
		if (!existsSync(VERBS_PATH)) return [];
		const data = JSON.parse(readFileSync(VERBS_PATH, "utf8")) as VerbsFile;
		return data.sections.flatMap((s) => s.verbs);
	} catch {
		return [];
	}
}

const VERBS = loadVerbs();

function pickVerb(): string {
	return VERBS[Math.floor(Math.random() * VERBS.length)]!;
}

function applyVerb(ctx: ExtensionContext, verb: string) {
	const { theme } = ctx.ui;
	ctx.ui.setWorkingIndicator({
		frames: SPINNER_FRAMES.map((g) => `${theme.fg("accent", verb)} ${theme.fg("dim", g)}`),
		intervalMs: 80,
	});
}

export default function (pi: ExtensionAPI) {
	if (VERBS.length === 0) return;

	pi.on("session_start", async (_event, ctx) => {
		applyVerb(ctx, pickVerb());
	});

	pi.on("turn_start", async (_event, ctx) => {
		applyVerb(ctx, pickVerb());
	});
}
