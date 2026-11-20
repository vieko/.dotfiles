// Unit tests for extensions/tab-title.ts (pure helpers only).
// Run: node --experimental-strip-types --test pi/.pi/agent/tests/tab-title.test.ts
import assert from "node:assert/strict";
import { test } from "node:test";
import { deriveName, focusText, normalizeTitle, titleFor } from "../extensions/tab-title.ts";

test("issue keys win, from text or Linear URLs", () => {
	assert.deepEqual(deriveName("Load Linear issue `GTMENG-5068` and warm up", "/tmp"), { name: "gtmeng-5068", source: "issue" });
	assert.equal(deriveName("https://linear.app/vercel/issue/GTMENG-4546/x", "/tmp")?.name, "gtmeng-4546");
	assert.equal(deriveName("see inc-8334 now", "/tmp")?.name, "inc-8334");
});

test("UUIDs in file names are not issue keys", () => {
	const d = deriveName("how can we improve naming on these Rex tabs? /var/x/pi-clipboard-39cbfede-e553-4331.png", "/tmp");
	assert.deepEqual(d, { name: "improve-naming-rex-tabs", source: "slug" });
});

test("utf-8 and sha-256 are not issue keys", () => {
	assert.equal(deriveName("fix the utf-8 bug in sha-256", "/tmp")?.source, "slug");
});

test("slugs drop paths, file names and request verbs, keep domains", () => {
	assert.equal(deriveName("Read pi/.pi/agent/x.ts and menu-shadow.ts, explain the flaky checkout test", "/tmp")?.name, "flaky-checkout-test");
	assert.match(deriveName("point viekoslavia.com to vieko.dev", "/tmp")?.name ?? "", /viekoslavia-com/);
});

test("a one-word slug waits for a better prompt", () => {
	assert.equal(deriveName("continue", "/tmp"), undefined);
	assert.equal(deriveName("/wrap", "/tmp"), undefined);
});

test("titles: one line, capitals only for keys the session writes in capitals, cut near 32 chars", () => {
	assert.equal(normalizeTitle('"gtmeng-5023 Notion import."', "Load GTMENG-5023"), "GTMENG-5023 Notion import");
	assert.equal(normalizeTitle("golem-5028 security review", "golem-5028/review-brief.md"), "golem-5028 security review");
	const long = normalizeTitle("Self-learning and human-in-the-loop patterns in workflows");
	assert.ok(long && long.length <= 32, long);
	assert.equal(normalizeTitle("none"), undefined);
});

test("focus lines: at most 16 words, no control characters", () => {
	const t = focusText(`Status: ${"word ".repeat(30)}\nsecond line`);
	assert.ok(t && t.split(" ").length <= 16 && t.endsWith("…"), t);
	assert.equal(focusText("Tests green, opening the PR."), "Tests green, opening the PR");
	assert.equal(focusText("a\u0007b"), "ab");
});

test("title precedence: explicit > AI title > instant name > folder", () => {
	assert.equal(titleFor("mine", "AI", "auto", "/x/gtm"), "mine");
	assert.equal(titleFor(undefined, "AI", "auto", "/x/gtm"), "AI");
	assert.equal(titleFor(undefined, undefined, "auto", "/x/gtm"), "auto");
	assert.equal(titleFor(undefined, undefined, undefined, "/x/gtm"), "gtm");
});

test("pi-post names from AI titles keep identifiers", async () => {
	const { kebabOf } = await import("../extensions/tab-title.ts");
	assert.equal(kebabOf("turn-clock.ts summary"), "turn-clock-ts-summary");
	assert.equal(kebabOf("GTMENG-5023 Notion import"), "gtmeng-5023-notion-import");
	assert.equal(kebabOf("#6642 lead scoring"), "6642-lead-scoring");
});
