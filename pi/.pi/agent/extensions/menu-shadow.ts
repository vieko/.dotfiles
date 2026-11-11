/**
 * menu-shadow
 *
 * Shadow mode for the "sent-back nudge" (docs/spawn-fleet-assessment.md,
 * proposal 1): when the agent stops on a lettered menu whose recommended
 * option is local and reversible, a live nudge would tell it to proceed.
 * This extension only measures. When a prompt answers such a menu it logs
 * what a live nudge would have done and what the user did. Nothing is shown
 * and nothing enters model context.
 *
 * Entry `menu-shadow` (never the option or reply text):
 *   rec      the recommended letter
 *   options  how many options the menu had
 *   verdict  "proceed" when the recommended option names no gated action,
 *            else "ask"
 *   gate     the word that made it "ask"
 *   reply    "rec" (took it unchanged), "rec-plus" (took it and added
 *            direction), "other" (another letter), "free" (a question or a
 *            redirect)
 *   waitMs   time from the menu to the reply
 *
 * session-audit prints verdict by reply. The go-live criteria are in the
 * session-audit skill, "Open experiments". `PI_MENU_SHADOW=off` turns it off.
 *
 * The menu parser and the reply classifier are the ones that produced the
 * 2026-11-03 baseline (~/scratch/data/menu-extract.mjs, menu-classify.mjs),
 * so the shadow log and the baseline count the same things.
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

export type Menu = { letters: string[]; options: Record<string, string>; rec: string | null };
export type Reply = "rec" | "rec-plus" | "other" | "free";

// Option line: "- **a)** ...", "a) ...", "(a) ...", "- (b) ...", "**(c)** ..."
const OPTION = /^\s*(?:[-*]\s+)?\**\(?([a-h])\)\**[.:]?\s+(.+)$/;

/** The lettered menu in the tail of an assistant message, or null. */
export function parseMenu(text: string): Menu | null {
	const found: Record<string, string> = {};
	for (const line of text.slice(-4000).split("\n")) {
		const m = OPTION.exec(line);
		if (m && !found[m[1]!]) found[m[1]!] = m[2]!.trim();
	}
	if (!found.a || !found.b) return null;
	const letters: string[] = [];
	for (const l of "abcdefgh") {
		if (found[l]) letters.push(l);
		else break;
	}
	const rec = letters.find((l) => /recommend/i.test(found[l]!)) ?? null;
	return { letters, options: Object.fromEntries(letters.map((l) => [l, found[l]!])), rec };
}

// Words in a recommended option that mean an external write, an action the
// destructive guard names, or a local step that cannot be undone. Tuned on the
// 145 hand labels of 2026-11-03: it holds all 30 that were not local and
// reversible, and passes 81 of the 115 that were.
const GATE =
	/\b(merge|push|deploy|publish|migrat\w*|db:push|force|prod(?:uction)?|delete|drop|send|post|release|tag|prs?|pull requests?|linear|issues?|comment|slack|re-?run|re-?request\w*|rm|kill|stop|remove|prune|sandbox|file it|reply|email|message|tell|close|reopen|restore|cancel|revert|reset|rotate|upload|install|upgrade|update pi|the apply|rehears\w*|reassign|to done)\b/i;

/** What a live nudge would do with this recommended option. */
export function verdictOf(option: string): { verdict: "proceed" | "ask"; gate?: string } {
	const hit = GATE.exec(option.replace(/[*`_]/g, ""));
	return hit ? { verdict: "ask", gate: hit[0].toLowerCase() } : { verdict: "proceed" };
}

function pick(reply: string): { letter: string | null; pure: boolean } {
	const s = reply
		.toLowerCase()
		.replace(/[*`_]/g, "")
		.replace(/\bw[a-z]{1,2}h\b/g, "with")
		.replace(/\bwent with\b/g, "proceed with")
		.trim();
	// A bare pick: "(a)", "a", "proceed with (a)", "go with b", "a please", "option a".
	const bare =
		/^(?:-\s*)?(?:ok[,.]?\s*|yes[,.]?\s*|sure[,.]?\s*)?(?:let'?s\s+)?(?:proceed|go|do|option|pick|choose|take)?(?:\s+(?:with|for))?\s*(?:option\s*)?\(?([a-h])\)?(?:\s*(?:please|pls|then))?[.!]?$/.exec(
			s,
		);
	if (bare) return { letter: bare[1]!, pure: true };
	if (s.length < 45 && /\b(as recommended|your recommendation|recommended (one|option))\b/.test(s)) return { letter: "REC", pure: true };
	if (/^(yes|go|ok|sure|do it|file it)\W*$/.test(s)) return { letter: "REC", pure: true };
	const loose = s.length < 45 ? [...s.matchAll(/(?:^|[\s(p])\(?([a-h])[)^]/g)].map((x) => x[1]!) : [];
	if (loose.length && loose.every((l) => l === loose[0])) {
		return { letter: loose[0]!, pure: /^(?:[\w']+\s+){0,3}\(?[a-h][)^]?\W*$/.test(s) || /^p?\(?[a-h][)^]$/.test(s) };
	}
	const typo = /^(?:let'?s\s+)?(?:proceed|continue|go|try)\s+\w{3,5}\s+\(?([a-h])\)?\W*$/.exec(s);
	if (typo) return { letter: typo[1]!, pure: true };
	const lead =
		/(?:^|\s|-)(?:proceed|go|do|option)(?:\s+(?:with|for))?\s*\(?([a-h])\)?(?=[\s,.;:!]|$)/.exec(s) ||
		/^\(?([a-h])\)(?=[\s,.;:]|$)/.exec(s) ||
		/^\(?([a-h])\)?[,.:;]\s/.exec(s);
	if (lead) return { letter: lead[1]!, pure: false };
	return { letter: null, pure: false };
}

/** How a reply answers a menu that marked a recommendation. */
export function classifyReply(reply: string, menu: Menu): Reply {
	const k = pick(reply);
	const letter = k.letter === "REC" ? menu.rec : k.letter;
	if (!letter || !menu.letters.includes(letter)) return "free";
	if (letter !== menu.rec) return "other";
	return k.pure ? "rec" : "rec-plus";
}

/** The text and time of the last message on the branch, when the assistant wrote it. */
function lastAssistantText(ctx: ExtensionContext): { text: string; at: number } | null {
	const branch = ctx.sessionManager.getBranch();
	for (let i = branch.length - 1; i >= 0; i--) {
		const e = branch[i]!;
		if (e.type !== "message") continue;
		if (e.message.role !== "assistant") return null;
		const text = e.message.content
			.filter((c): c is { type: "text"; text: string } => c.type === "text")
			.map((c) => c.text)
			.join("\n");
		return text.trim() ? { text, at: new Date(e.timestamp).getTime() } : null;
	}
	return null;
}

export default function (pi: ExtensionAPI) {
	if (process.env.PI_MENU_SHADOW === "off") return;

	pi.on("input", (event, ctx) => {
		if (event.source !== "interactive" || event.streamingBehavior) return;
		const reply = event.text.trim();
		if (!reply || reply.startsWith("!")) return;
		try {
			const last = lastAssistantText(ctx);
			const menu = last && parseMenu(last.text);
			if (!last || !menu || !menu.rec) return;
			pi.appendEntry("menu-shadow", {
				rec: menu.rec,
				options: menu.letters.length,
				...verdictOf(menu.options[menu.rec]!),
				reply: classifyReply(reply, menu),
				waitMs: Date.now() - last.at,
			});
		} catch {
			// Measurement only: a failure here must not touch the prompt.
		}
	});
}
