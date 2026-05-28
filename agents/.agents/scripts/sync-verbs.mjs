#!/usr/bin/env node
/**
 * sync-verbs.mjs
 *
 * Source of truth: ~/.dotfiles/agents/.agents/verbs.json (structured by section).
 *
 * Targets:
 *   - ~/dev/forge/src/display.ts          AGENT_VERBS array (with section comments)
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
const FORGE = join(ROOT, "dev/forge/src/display.ts");
const CLAUDE = join(ROOT, ".dotfiles/claude/.claude/settings.json");

const check = process.argv.includes("--check");

function loadVerbs() {
	const data = JSON.parse(readFileSync(SRC, "utf8"));
	const flat = data.sections.flatMap((s) => s.verbs);
	return { data, flat };
}

function tsEscape(v) {
	return v.replace(/\\/g, "\\\\").replace(/'/g, "\\'");
}

function renderForgeBlock({ sections }) {
	const lines = ["export const AGENT_VERBS = ["];
	for (const sec of sections) {
		lines.push(`  // ${sec.name} (${sec.verbs.length})`);
		for (const v of sec.verbs) lines.push(`  '${tsEscape(v)}',`);
	}
	lines.push("];");
	return lines.join("\n");
}

function syncForge({ data }) {
	if (!existsSync(FORGE)) {
		console.log(`[skip] ${FORGE} not found`);
		return { changed: false, skipped: true };
	}
	const src = readFileSync(FORGE, "utf8");
	const re = /export const AGENT_VERBS = \[[\s\S]*?\n\];/;
	if (!re.test(src)) throw new Error("AGENT_VERBS block not found in display.ts");
	const next = src.replace(re, renderForgeBlock(data));
	if (next === src) return { changed: false };
	if (!check) writeFileSync(FORGE, next);
	return { changed: true };
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
	forge: syncForge(verbs),
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
