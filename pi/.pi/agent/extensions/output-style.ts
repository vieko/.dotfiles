/**
 * Output Style Extension
 *
 * Consolidates how prose is output regardless of the model. Two layers:
 *
 * 1. Always-on prose contract - appended to the system prompt on every turn,
 *    normalizing cross-model prose habits (BLUF, no bullet-splatter, no em
 *    dashes, no essay-bot hedging). Override the built-in contract by creating
 *    `~/.pi/agent/output-styles/contract.md` (body only, no frontmatter needed).
 *
 * 2. Named switchable styles - Claude Code-inspired built-ins (default,
 *    proactive, explanatory, learning) plus `ste` (ASD-STE100 Simplified
 *    Technical English). Custom styles are Markdown files with frontmatter
 *    (`name`, `description`) in:
 *      - `~/.pi/agent/output-styles/*.md` (user)
 *      - `.pi/output-styles/*.md`         (project, trusted only, wins by name)
 *
 * Usage:
 *   /style             - picker
 *   /style <name>      - switch directly (autocompletes)
 *   /style default     - back to contract-only
 *   pi --style <name>  - start with a style
 *
 * Unlike Claude Code, style changes take effect on the next prompt - no /clear
 * needed - because the prompt is rebuilt via before_agent_start on every turn.
 * The active style persists in the session and survives resume/fork.
 */

import { existsSync, readdirSync, readFileSync } from "node:fs";
import { basename, join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { CONFIG_DIR_NAME, getAgentDir } from "@earendil-works/pi-coding-agent";

interface Style {
	name: string;
	description: string;
	instructions: string;
	source: "builtin" | "user" | "project";
}

const DEFAULT_CONTRACT = `## Prose Contract (always on)

Follow these rules for all prose addressed to the user, regardless of which model you are:

- Lead with the answer or result (BLUF). No preamble, no restating the question, no compliments about the question.
- Match response length to the request. A short question gets a short answer.
- Write in sentences. Use bullets only for truly enumerable items (files, options, steps), never as a substitute for prose. Do not add headings to short replies.
- Do not use em dashes. Use "--", or restructure with a colon, semicolon, or comma.
- Value first: when presenting a change, PR, or proposal, state what it brings to the table before explaining mechanism.
- State each tradeoff or caveat once. Do not hedge repeatedly or balance every statement with a counterpoint.
- No sycophancy, no filler ("Certainly!", "Great question"), no closing recap of what you just said.
- Keep reasoning in answers minimal by default; expand only when the user asks to understand or teach.
- Plain, matter-of-fact register. Precision over polish; do not write like a press release or a thought-leadership post.`;

const BUILTIN_STYLES: Style[] = [
	{
		name: "default",
		description: "Prose contract only: BLUF, concise, matter-of-fact",
		instructions: "",
		source: "builtin",
	},
	{
		name: "proactive",
		description: "Execute immediately, minimize interruptions, prefer action over planning",
		instructions: `Execute immediately. Make reasonable assumptions instead of pausing for routine decisions, and prefer action over planning. Do not ask for confirmation on routine, reversible steps; report what you did instead. This never overrides explicit safety rules from project instructions: destructive or irreversible operations still require user approval.`,
		source: "builtin",
	},
	{
		name: "explanatory",
		description: "Explain implementation choices and codebase patterns while working",
		instructions: `Provide educational insights while completing tasks. After significant changes or decisions, add a short "Insight:" note (2-4 sentences) explaining the implementation choice, the relevant codebase pattern, or the tradeoff taken. Keep everything outside the insights within the prose contract.`,
		source: "builtin",
	},
	{
		name: "learning",
		description: "Collaborative learn-by-doing: user writes small pieces of code",
		instructions: `Collaborative, learn-by-doing mode. Share brief insights while coding, and ask the user to contribute small, strategic pieces of code themselves. When you want the user to implement something, insert a TODO(human) marker in the code with a one-line description of what to implement, then stop and wait for their contribution before continuing.`,
		source: "builtin",
	},
	{
		name: "ste",
		description: "ASD-STE100 Simplified Technical English",
		instructions: `Write all prose to the user in ASD-STE100 Simplified Technical English:

- Use the active voice. Make the doer of the action the subject of the sentence.
- Keep sentences short: maximum 20 words in instructions, 25 words in descriptions.
- Give one instruction per sentence. Write one topic per paragraph, maximum 6 sentences.
- Use the simple present tense unless a different tense is necessary.
- Use one word for one meaning, and the same word for the same thing every time. Do not vary vocabulary for elegance.
- Do not make noun clusters of more than three nouns.
- Use articles (a, an, the) where English permits. Do not telegraph.
- In warnings and cautions, give the condition first, then the instruction.`,
		source: "builtin",
	},
];

/** Reserved filename for the contract override; never listed as a style. */
const CONTRACT_FILENAME = "contract.md";

/** Minimal frontmatter parse: returns { fields, body }. */
function parseFrontmatter(raw: string): { fields: Record<string, string>; body: string } {
	const fields: Record<string, string> = {};
	if (!raw.startsWith("---")) return { fields, body: raw.trim() };
	const end = raw.indexOf("\n---", 3);
	if (end === -1) return { fields, body: raw.trim() };
	const header = raw.slice(3, end);
	for (const line of header.split("\n")) {
		const idx = line.indexOf(":");
		if (idx === -1) continue;
		const key = line.slice(0, idx).trim();
		const value = line
			.slice(idx + 1)
			.trim()
			.replace(/^["']|["']$/g, "");
		if (key) fields[key] = value;
	}
	const body = raw.slice(end + 4).replace(/^-*\s*/, "").trim();
	return { fields, body };
}

function loadStylesFromDir(dir: string, source: "user" | "project"): Style[] {
	if (!existsSync(dir)) return [];
	const styles: Style[] = [];
	let entries: string[];
	try {
		entries = readdirSync(dir);
	} catch {
		return [];
	}
	for (const file of entries) {
		if (!file.endsWith(".md") || file.toLowerCase() === CONTRACT_FILENAME) continue;
		try {
			const raw = readFileSync(join(dir, file), "utf-8");
			const { fields, body } = parseFrontmatter(raw);
			if (!body) continue;
			styles.push({
				name: (fields.name ?? basename(file, ".md")).toLowerCase().replace(/\s+/g, "-"),
				description: fields.description ?? body.split("\n")[0].slice(0, 80),
				instructions: body,
				source,
			});
		} catch {
			// Unreadable style file: skip.
		}
	}
	return styles;
}

function loadContractOverride(): string | undefined {
	const path = join(getAgentDir(), "output-styles", CONTRACT_FILENAME);
	if (!existsSync(path)) return undefined;
	try {
		const { body } = parseFrontmatter(readFileSync(path, "utf-8"));
		return body || undefined;
	} catch {
		return undefined;
	}
}

export default function outputStyleExtension(pi: ExtensionAPI) {
	let styles: Style[] = [...BUILTIN_STYLES];
	let contract = DEFAULT_CONTRACT;
	let activeStyle: Style = BUILTIN_STYLES[0];

	pi.registerFlag("style", {
		description: "Output style to activate at startup",
		type: "string",
	});

	function findStyle(name: string): Style | undefined {
		return styles.find((s) => s.name === name.toLowerCase());
	}

	/** Later sources win by name: builtin < user < project. */
	function loadAll(ctx: ExtensionContext) {
		contract = loadContractOverride() ?? DEFAULT_CONTRACT;
		const merged = new Map<string, Style>();
		for (const s of BUILTIN_STYLES) merged.set(s.name, s);
		for (const s of loadStylesFromDir(join(getAgentDir(), "output-styles"), "user")) {
			merged.set(s.name, s);
		}
		if (ctx.isProjectTrusted()) {
			for (const s of loadStylesFromDir(join(ctx.cwd, CONFIG_DIR_NAME, "output-styles"), "project")) {
				merged.set(s.name, s);
			}
		}
		styles = [...merged.values()];
	}

	function updateStatus(ctx: ExtensionContext) {
		if (activeStyle.name === "default") {
			ctx.ui.setStatus("output-style", undefined);
		} else {
			ctx.ui.setStatus("output-style", ctx.ui.theme.fg("accent", `style:${activeStyle.name}`));
		}
	}

	function setStyle(style: Style, ctx: ExtensionContext, persist: boolean) {
		activeStyle = style;
		if (persist) pi.appendEntry("output-style", { style: style.name });
		updateStatus(ctx);
	}

	pi.registerCommand("style", {
		description: "Switch output style (prose contract is always on)",
		getArgumentCompletions: (prefix: string) => {
			const items = styles
				.filter((s) => s.name.startsWith(prefix.toLowerCase()))
				.map((s) => ({ value: s.name, label: `${s.name} -- ${s.description}` }));
			return items.length > 0 ? items : null;
		},
		handler: async (args, ctx) => {
			loadAll(ctx); // pick up edits to style files without /reload

			const requested = args?.trim().toLowerCase();
			if (requested) {
				const style = findStyle(requested);
				if (!style) {
					ctx.ui.notify(`Unknown style "${requested}". Available: ${styles.map((s) => s.name).join(", ")}`, "error");
					return;
				}
				setStyle(style, ctx, true);
				ctx.ui.notify(`Output style: ${style.name}`, "info");
				return;
			}

			if (!ctx.hasUI) return;
			const labels = styles.map(
				(s) => `${s.name === activeStyle.name ? "* " : "  "}${s.name.padEnd(14)} ${s.description}`,
			);
			const choice = await ctx.ui.select("Output style (contract always on)", labels);
			if (!choice) return;
			const style = findStyle(choice.slice(2).trim().split(/\s+/)[0]);
			if (style) {
				setStyle(style, ctx, true);
				ctx.ui.notify(`Output style: ${style.name}`, "info");
			}
		},
	});

	// Inject contract + active style on every turn, whatever the model.
	pi.on("before_agent_start", async (event) => {
		const parts = [event.systemPrompt, contract];
		if (activeStyle.instructions) {
			parts.push(`## Output Style: ${activeStyle.name}\n\n${activeStyle.instructions}`);
		}
		return { systemPrompt: parts.join("\n\n") };
	});

	pi.on("session_start", async (_event, ctx) => {
		loadAll(ctx);

		// CLI flag wins, then persisted session state, then default.
		const flag = pi.getFlag("style");
		if (typeof flag === "string" && flag) {
			const style = findStyle(flag);
			if (style) {
				setStyle(style, ctx, true);
				return;
			}
			ctx.ui.notify(`Unknown style "${flag}". Available: ${styles.map((s) => s.name).join(", ")}`, "warning");
		}

		let restored: string | undefined;
		for (const entry of ctx.sessionManager.getEntries()) {
			if (entry.type === "custom" && entry.customType === "output-style") {
				restored = (entry.data as { style?: string } | undefined)?.style;
			}
		}
		if (restored) {
			const style = findStyle(restored);
			if (style) activeStyle = style;
		}
		updateStatus(ctx);
	});

	pi.on("session_shutdown", async (_event, ctx) => {
		ctx.ui.setStatus("output-style", undefined);
	});
}
