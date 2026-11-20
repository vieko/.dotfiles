// Prompt eval for extensions/tab-title.ts against your own recent sessions.
// Prints model output next to the first prompt so a person can judge it;
// no session data is stored. Needs AI_GATEWAY_API_KEY.
//
//   node --experimental-strip-types pi/.pi/agent/tests/tab-title-eval.mts [title|focus|outcome] [count]
//   EVAL_MODEL=anthropic/claude-haiku-4.5 (default)
import { readdirSync, readFileSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import * as m from "../extensions/tab-title.ts";

const mode = process.argv[2] ?? "title";
const count = Number(process.argv[3] ?? 40);
const model = process.env.EVAL_MODEL ?? "anthropic/claude-haiku-4.5";

type Part = { type: string; text?: string; name?: string; arguments?: unknown };
const textOf = (c: string | Part[]) => (typeof c === "string" ? c : c.map((p) => (p.type === "text" ? p.text ?? "" : "")).join(" "));

interface Sample { name?: string; user: string; reply: string; mid?: { request: string; steps: string[] } }

function samples(): Sample[] {
	const root = join(homedir(), ".pi", "agent", "sessions");
	const files = readdirSync(root).flatMap((d) => {
		try {
			return readdirSync(join(root, d)).filter((f) => f.endsWith(".jsonl")).map((f) => join(root, d, f));
		} catch {
			return [];
		}
	});
	files.sort((a, b) => statSync(b).mtimeMs - statSync(a).mtimeMs);
	const out: Sample[] = [];
	for (const f of files) {
		if (out.length >= count) break;
		let user: string | undefined, reply: string | undefined, name: string | undefined, users = 0;
		let mid: Sample["mid"];
		for (const line of readFileSync(f, "utf8").split("\n")) {
			if (!line) continue;
			let e: any;
			try { e = JSON.parse(line); } catch { continue; }
			if (e.type === "session_info") name = e.name;
			if (e.type !== "message") continue;
			const msg = e.message;
			if (msg.role === "user") {
				const t = textOf(msg.content).trim();
				if (!t) continue;
				users++;
				user ??= t;
				if (users === 3) mid = { request: t, steps: [] };
			} else if (msg.role === "assistant") {
				if (user && !reply) reply = textOf(msg.content).trim() || undefined;
				if (mid && mid.steps.length < 14)
					for (const c of msg.content as Part[]) {
						if (c.type === "text" && c.text?.trim()) mid.steps.push(`said: ${c.text.slice(0, 300)}`);
						else if (c.type === "toolCall") mid.steps.push(`tool ${c.name}: ${JSON.stringify(c.arguments ?? {}).slice(0, 160)}`);
					}
			}
		}
		if (user && reply) out.push({ name, user: user.slice(0, 2000), reply: reply.slice(0, 1200), mid });
	}
	return out;
}

async function ask(system: string, user: string): Promise<string> {
	const r = await fetch("https://ai-gateway.vercel.sh/v1/chat/completions", {
		method: "POST",
		headers: { "content-type": "application/json", authorization: `Bearer ${process.env.AI_GATEWAY_API_KEY}` },
		body: JSON.stringify({ model, max_tokens: 200, messages: [{ role: "system", content: system }, { role: "user", content: user }] }),
	});
	const j: any = await r.json();
	return j.choices?.[0]?.message?.content ?? `ERR ${JSON.stringify(j).slice(0, 200)}`;
}

const one = (s: string, n: number) => s.replace(/\s+/g, " ").slice(0, n);

const rows = await Promise.all(
	samples().map(async (d) => {
		if (mode === "title") {
			const raw = await ask(m.TITLE_PROMPT, m.titleInput(d.user, d.reply));
			return `${(m.normalizeTitle(raw, `${d.user}\n${d.reply}`) ?? "∅").padEnd(34)} | ${one(d.user, 70)}`;
		}
		if (!d.mid) return null;
		const ctx = d.name ? `SESSION: ${d.name}\n\n` : "";
		const first = d.mid.request.length < 120 ? `SESSION'S FIRST REQUEST:\n${d.user.slice(0, 400)}\n\n` : "";
		const digest = `${ctx}${first}USER'S LATEST REQUEST:\n${d.mid.request.slice(0, 1500)}\n\nRECENT STEPS (oldest first):\n${d.mid.steps.slice(-12).join("\n")}`;
		if (mode === "outcome") {
			const final = (d.mid.steps.filter((s) => s.startsWith("said:")).at(-1) ?? "").slice(5);
			const raw = await ask(m.OUTCOME_PROMPT, `<digest>\n${digest}\n\nAGENT'S FINAL MESSAGE:\n${final}\n</digest>`);
			return `${m.focusText(raw) ?? "∅"}\n    ↳ ${one(d.mid.request, 90)}`;
		}
		const raw = await ask(m.FOCUS_PROMPT, `PREVIOUS LINE: \n\n<digest>\n${digest}\n</digest>`);
		return `${m.focusText(raw) ?? "∅"}\n    ↳ ${one(d.mid.request, 90)}`;
	}),
);
console.log(rows.filter(Boolean).join("\n"));
