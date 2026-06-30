#!/usr/bin/env node
/**
 * sync-verbs.mjs
 *
 * Source of truth: ~/.dotfiles/agents/.agents/verbs.json (structured by section).
 *
 * Targets:
 *   - ~/.dotfiles/claude/.claude/settings.json   spinnerVerbs.verbs (flat array)
 *
 * Pi reads verbs.json at runtime via the spinner-verbs extension; nothing to
 * regenerate there.
 *
 * Usage:
 *   node ~/.dotfiles/agents/.agents/scripts/sync-verbs.mjs
 *   node ~/.dotfiles/agents/.agents/scripts/sync-verbs.mjs --check    # dry-run, exit 1 if drift
 */

import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const ROOT = homedir();
const SRC = join(ROOT, ".dotfiles/agents/.agents/verbs.json");
const CLAUDE = join(ROOT, ".dotfiles/claude/.claude/settings.json");

const check = process.argv.includes("--check");

function loadVerbs() {
	const data = JSON.parse(readFileSync(SRC, "utf8"));
	const flat = data.sections.flatMap((s) => s.verbs);
	return { data, flat };
}

function syncClaude({ flat }) {
	if (!existsSync(CLAUDE)) {
		console.log(`[skip] ${CLAUDE} not found`);
		return { changed: false, skipped: true };
	}
	const src = readFileSync(CLAUDE, "utf8");
	const json = JSON.parse(src);
	json.spinnerVerbs ??= { mode: "replace", verbs: [] };
	json.spinnerVerbs.verbs = flat;
	const next = JSON.stringify(json, null, 2) + "\n";
	if (next === src) return { changed: false };
	if (!check) writeFileSync(CLAUDE, next);
	return { changed: true };
}

const verbs = loadVerbs();
console.log(`source: ${verbs.flat.length} verbs across ${verbs.data.sections.length} sections`);

const results = {
	claude: syncClaude(verbs),
};

for (const [name, res] of Object.entries(results)) {
	if (res.skipped) continue;
	const label = check ? (res.changed ? "DRIFT" : "ok") : res.changed ? "wrote" : "ok";
	console.log(`  ${name.padEnd(8)} ${label}`);
}

if (check && Object.values(results).some((r) => r.changed)) {
	console.error("drift detected — run without --check to sync");
	process.exit(1);
}
