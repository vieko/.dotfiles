/**
 * context-cost
 *
 * Cost-aware context guard. pi's auto-compaction only fires near the model's
 * window (1M on current Claude models: never in practice), and prompt caching
 * makes a long session cheap per turn but brutal on two events: the cache
 * expiring while you step away (the whole prefix is rewritten on the next
 * turn, at the 1h write rate = 2x input on Anthropic), and just being large
 * (every turn reads the full prefix; every miss costs a full rewrite). The
 * week-36 audit put 65% of spend on the 39% of turns above 200K tokens, and
 * ~$230 on 54 resume-after-idle rewrites alone.
 *
 * What it does, in dollars the model's own cost table produces:
 * - on resume, and on the first input after the cache TTL has lapsed with a
 *   large context: say what the next turn will rewrite and cost, and offer
 *   "compact first" / "send anyway" / "keep my input" (the dialog fires once
 *   per expiry, never mid-stream, never for slash commands);
 * - every 100K tokens above the warn threshold: one notice with per-turn read
 *   cost and full-miss cost, so the number is in view before it hurts;
 * - `/ctx`: the same numbers on demand.
 *
 * It never compacts or clears on its own. Thresholds: PI_CTX_WARN_TOKENS
 * (default 150000). TTL follows PI_CACHE_RETENTION: long = 1h on
 * anthropic-messages (30m on OpenAI Responses), otherwise 5m.
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const WARN_TOKENS = Number(process.env.PI_CTX_WARN_TOKENS) || 150_000;
const STEP_TOKENS = 100_000;
const COMPACT_KEEP_TOKENS = 20_000; // pi's compaction.keepRecentTokens default

interface Rates {
	input: number;
	output: number;
	cacheRead: number;
	cacheWrite: number;
	tiers?: Array<{ inputTokensAbove: number; input: number; output: number; cacheRead: number; cacheWrite: number }>;
}

interface Pricing {
	readPerM: number;
	writePerM: number;
	inputPerM: number;
	ttlMin: number;
	longRetention: boolean;
}

function pricing(ctx: ExtensionContext, tokens: number): Pricing | undefined {
	const model = ctx.model;
	const cost = (model as { cost?: Rates } | undefined)?.cost;
	if (!model || !cost) return undefined;
	let rates: Rates = cost;
	for (const tier of cost.tiers ?? []) if (tokens > tier.inputTokensAbove) rates = tier;
	const longRetention = process.env.PI_CACHE_RETENTION === "long";
	const anthropic = model.api === "anthropic-messages";
	// Anthropic bills 1h cache writes at 2x input; 5m writes at the table rate.
	const writePerM = anthropic && longRetention ? rates.input * 2 : rates.cacheWrite;
	const ttlMin = longRetention ? (anthropic ? 60 : 30) : 5;
	return { readPerM: rates.cacheRead, writePerM, inputPerM: rates.input, ttlMin, longRetention };
}

const usd = (x: number) => (x >= 10 ? `$${x.toFixed(0)}` : `$${x.toFixed(2)}`);
const ktok = (n: number) => (n >= 1_000_000 ? `${(n / 1e6).toFixed(2)}M` : `${Math.round(n / 1000)}K`);
const mins = (ms: number) => {
	const m = Math.round(ms / 60000);
	return m >= 120 ? `${Math.round(m / 60)}h` : `${m}m`;
};

export default function (pi: ExtensionAPI) {
	let lastRequestAt: number | null = null;
	let lastStep = 0;
	let askedForExpiryAt: number | null = null; // lastRequestAt value we already prompted about

	const scanLastRequest = (ctx: ExtensionContext) => {
		lastRequestAt = null;
		for (const entry of ctx.sessionManager.getBranch()) {
			const e = entry as { type: string; timestamp?: string; message?: { role?: string } };
			if (e.type === "message" && e.message?.role === "assistant" && e.timestamp) {
				lastRequestAt = new Date(e.timestamp).getTime();
			}
		}
	};

	const snapshot = (ctx: ExtensionContext) => {
		const usage = ctx.getContextUsage();
		const tokens = usage?.tokens ?? null;
		if (tokens === null) return undefined;
		const p = pricing(ctx, tokens);
		if (!p) return undefined;
		const idleMs = lastRequestAt === null ? null : Date.now() - lastRequestAt;
		const expired = idleMs !== null && idleMs > p.ttlMin * 60_000;
		return {
			tokens,
			percent: usage?.percent ?? null,
			p,
			idleMs,
			expired,
			readCost: (tokens * p.readPerM) / 1e6,
			missCost: (tokens * p.writePerM) / 1e6,
			// Compaction re-reads the summarized span uncached, then the next turn writes ~keepRecent + summary.
			compactCost: (tokens * p.inputPerM) / 1e6 + ((COMPACT_KEEP_TOKENS + 4_000) * p.writePerM) / 1e6,
		};
	};

	pi.on("session_start", (event, ctx) => {
		scanLastRequest(ctx);
		lastStep = 0;
		askedForExpiryAt = null;
		if (!ctx.hasUI) return;
		const s = snapshot(ctx);
		if (!s || s.tokens < WARN_TOKENS) return;
		if (s.expired && s.idleMs !== null) {
			ctx.ui.notify(
				`Prompt cache expired (idle ${mins(s.idleMs)} > ${s.p.ttlMin}m TTL). Next turn rewrites ${ktok(s.tokens)} tokens ≈ ${usd(s.missCost)}. ` +
					`/compact ≈ ${usd(s.compactCost)} once then ~${ktok(COMPACT_KEEP_TOKENS)}/turn; /new is free. (${event.reason})`,
				"warning",
			);
		} else {
			ctx.ui.notify(
				`Context ${ktok(s.tokens)}: each turn reads ≈ ${usd(s.readCost)}, a cache miss costs ≈ ${usd(s.missCost)}. /ctx for details.`,
				"info",
			);
		}
	});

	pi.on("turn_end", (_event, ctx) => {
		lastRequestAt = Date.now();
		askedForExpiryAt = null;
		if (!ctx.hasUI) return;
		const s = snapshot(ctx);
		if (!s || s.tokens < WARN_TOKENS) return;
		const step = Math.floor(s.tokens / STEP_TOKENS);
		if (step <= lastStep) return;
		lastStep = step;
		ctx.ui.notify(
			`Context ${ktok(s.tokens)}${s.percent !== null ? ` (${Math.round(s.percent)}%)` : ""}: each turn now reads ≈ ${usd(s.readCost)}; a full cache miss costs ≈ ${usd(s.missCost)} at the ${s.p.longRetention ? "1h" : "5m"} write rate. /compact ≈ ${usd(s.compactCost)}.`,
			"info",
		);
	});

	pi.on("input", async (event, ctx) => {
		if (!ctx.hasUI || event.source !== "interactive" || event.streamingBehavior) return;
		if (event.text.trimStart().startsWith("/")) return;
		const s = snapshot(ctx);
		if (!s || !s.expired || s.tokens < WARN_TOKENS || s.idleMs === null) return;
		if (askedForExpiryAt === lastRequestAt) return; // already answered for this gap
		askedForExpiryAt = lastRequestAt;

		const compactFirst = `Compact first (≈ ${usd(s.compactCost)} once, then ~${ktok(COMPACT_KEEP_TOKENS)} tokens/turn)`;
		const sendAnyway = `Send anyway (rewrites ${ktok(s.tokens)} ≈ ${usd(s.missCost)}, then ≈ ${usd(s.readCost)}/turn)`;
		const keep = "Keep my input in the editor, decide later (/new is free)";
		const choice = await ctx.ui.select(
			`Prompt cache expired: idle ${mins(s.idleMs)} > ${s.p.ttlMin}m TTL with ${ktok(s.tokens)} tokens of context`,
			[compactFirst, sendAnyway, keep],
		);
		if (choice === compactFirst) {
			const content = event.images?.length
				? [{ type: "text" as const, text: event.text }, ...event.images]
				: event.text;
			ctx.compact({
				onComplete: () => {
					ctx.ui.notify("Compacted; sending your message.", "info");
					pi.sendUserMessage(content, { expandPromptTemplates: true });
				},
				onError: (error) => {
					ctx.ui.setEditorText(event.text);
					ctx.ui.notify(`Compaction failed (${error.message}); your input is back in the editor.`, "error");
				},
			});
			return { action: "handled" as const };
		}
		if (choice === keep || choice === undefined) {
			ctx.ui.setEditorText(event.text);
			return { action: "handled" as const };
		}
		return { action: "continue" as const };
	});

	pi.registerCommand("ctx", {
		description: "Context size, cache TTL status, and what the next turn, a miss, or a compaction costs",
		handler: async (_args, ctx) => {
			const s = snapshot(ctx);
			if (!s) {
				ctx.ui.notify("No usage yet (or the model has no cost table).", "info");
				return;
			}
			const model = ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : "?";
			const idle = s.idleMs === null ? "no request yet" : `${mins(s.idleMs)} since last request`;
			const cache = s.idleMs === null ? "" : s.expired ? `, cache EXPIRED (${s.p.ttlMin}m TTL)` : `, cache warm (${s.p.ttlMin}m TTL)`;
			ctx.ui.notify(
				[
					`${model}: ${ktok(s.tokens)} tokens${s.percent !== null ? ` (${Math.round(s.percent)}% of window)` : ""}, ${idle}${cache}.`,
					`Per turn ≈ ${usd(s.readCost)} in cache reads (${s.p.readPerM}/M). Full miss ≈ ${usd(s.missCost)} (${s.p.writePerM}/M ${s.p.longRetention ? "1h" : "5m"} write).`,
					`/compact ≈ ${usd(s.compactCost)} once, then ~${ktok(COMPACT_KEEP_TOKENS)} tokens/turn. /new is free.`,
				].join("\n"),
				s.expired && s.tokens >= WARN_TOKENS ? "warning" : "info",
			);
		},
	});
}
