/**
 * question-status
 *
 * Reports a turn that ends on a lettered menu as `blocked` (kind
 * `question`) over OSC 7501, so Rex's Activity list, tab marks and
 * notifications show which sessions wait for an answer. Pi itself reports
 * such a turn as `done`, the same as finished work.
 *
 * Pi writes the root status record and its API has no record id, so this
 * extension writes a child record (`id=question`) beside it. The two never
 * overwrite each other. The record is cleared on the next prompt, on a new
 * run, on a session switch and on shutdown; terminals also drop `blocked`
 * records when the process exits.
 *
 * The menu parser is the one behind the 2026-11-03 menu baseline;
 * tab-title imports it from here. The row text names the options and the recommended one, never
 * the reply. `PI_QUESTION_STATUS=off` turns it off.
 *
 * Spec: https://www.superlogical.com/rex/docs/build/program-status
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

export type Menu = { letters: string[]; options: Record<string, string>; rec: string | null };

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

const ID = "question";
const MAX_MSG = 160;

function b64(text: string): string {
	return Buffer.from(text, "utf8").toString("base64");
}

/** One plain line: markdown marks and control characters removed, cut to MAX_MSG. */
function plain(text: string): string {
	const s = text
		.replace(/[*`_#]/g, "")
		.replace(/[\x00-\x1f\x7f]+/g, " ")
		.replace(/\s+/g, " ")
		.trim();
	return s.length > MAX_MSG ? `${s.slice(0, MAX_MSG - 1)}…` : s;
}

/** Row text, e.g. "Choose a-c; recommends (a) Build the pi extension that writes…". */
export function messageOf(menu: Menu): string {
	const range = `${menu.letters[0]}-${menu.letters.at(-1)}`;
	if (!menu.rec) return plain(`Choose ${range}`);
	const option = menu.options[menu.rec]!.replace(/\(?\brecommended\b\)?[:.]?/i, "");
	return plain(`Choose ${range}; recommends (${menu.rec}) ${option}`);
}

export function blockedReport(message: string, title?: string): string {
	const pairs = [`state=blocked`, `id=${ID}`, `app=pi`, `kind=question`];
	if (title) pairs.push(`title=${b64(plain(title))}`);
	pairs.push(`msg=${b64(message)}`);
	return `\x1b]7501;${pairs.join(":")}\x1b\\`;
}

export const CLEAR_REPORT = `\x1b]7501;state=clear:id=${ID}\x1b\\`;

/** Text of the last assistant message on the branch, if it is the leaf. */
function lastAssistantText(ctx: ExtensionContext): string | null {
	const branch = ctx.sessionManager.getBranch();
	for (let i = branch.length - 1; i >= 0; i--) {
		const e = branch[i]!;
		if (e.type !== "message") continue;
		if (e.message.role !== "assistant") return null;
		return e.message.content
			.filter((c): c is { type: "text"; text: string } => c.type === "text")
			.map((c) => c.text)
			.join("\n");
	}
	return null;
}

export default function (pi: ExtensionAPI) {
	if (process.env.PI_QUESTION_STATUS === "off" || !process.stdout.isTTY) return;

	let shown = false;

	const write = (seq: string) => {
		try {
			process.stdout.write(seq);
		} catch {
			// Status only: a failed write must not touch the session.
		}
	};
	const clear = () => {
		if (!shown) return;
		shown = false;
		write(CLEAR_REPORT);
	};

	pi.on("agent_settled", (event, ctx) => {
		if (!ctx.hasUI || event.aborted) return clear();
		try {
			const text = lastAssistantText(ctx);
			const menu = text ? parseMenu(text) : null;
			if (!menu) return clear();
			write(blockedReport(messageOf(menu), ctx.sessionManager.getSessionName()));
			shown = true;
		} catch {
			clear();
		}
	});

	pi.on("input", () => clear());
	pi.on("agent_start", () => clear());
	pi.on("session_start", () => clear());
	pi.on("session_shutdown", () => clear());
}
