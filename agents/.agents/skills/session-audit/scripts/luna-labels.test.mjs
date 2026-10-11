#!/usr/bin/env node
// Exercise the codemode pass with local model mocks; never call a provider.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const source = readFileSync(new URL("../references/luna-labels.js", import.meta.url), "utf8");
const rubric = JSON.parse(readFileSync(new URL("../references/luna-rubric.json", import.meta.url), "utf8"));
const execute = new (Object.getPrototypeOf(async function () {}).constructor)("tools", "models", "text", source);
const fixture = { since: 1, until: 2, sessions: [
	{ dir: "fixture", file: "one", prompts: ["Implement the requested fix", "proceed with (a)"], reports: ["Completed. Verification: PASS.", "Blocked: ENOENT."] },
	{ dir: "fixture", file: "two", prompts: ["Look up this model", "posted..."], reports: ["Done. Deviations: none."] },
] };
const run = async (models, audit = fixture) => {
	let saved;
	const tools = {
		bash: async () => ({ output: "/tmp/fixture" }),
		read: async ({ path }) => JSON.stringify(path.endsWith("luna-rubric.json") ? rubric : audit),
		write: async ({ content }) => { saved = JSON.parse(content); },
	};
	await execute(tools, models, () => {});
	return saved;
};

test("v2 labels only opener intent and report evidence, with at most four concurrent calls", async () => {
	const calls = [];
	let active = 0;
	let maxActive = 0;
	const saved = await run({
		getModelOfType: async () => ({}),
		classify: async (_, context) => {
			calls.push(context);
			maxActive = Math.max(maxActive, ++active);
			await new Promise(resolve => setImmediate(resolve));
			active--;
			return { stopReason: "stop", answers: {}, usage: { cost: { total: 0.001 } } };
		},
	});
	assert.deepEqual(Object.keys(rubric), ["version", "questions"]);
	assert.equal(rubric.version, 2);
	assert.deepEqual(Object.keys(rubric.questions), ["intent", "has_verification", "lists_deviations"]);
	assert.equal(maxActive, 4);
	assert.equal(saved.labels.length, 5);
	assert.equal(saved.cost, 0.005);
	assert.equal(saved.budget, 0.10);
	assert.deepEqual(calls[0].state, { prompts: ["Implement the requested fix"] });
	assert.deepEqual(calls[3].state, { prompts: ["Look up this model"] });
	assert.deepEqual(Object.keys(calls[0].questions), ["intent"]);
	assert.deepEqual(Object.keys(calls[1].questions), ["has_verification", "lists_deviations"]);
});

test("classifier errors and thrown calls fail open", async () => {
	for (const classify of [
		async () => ({ stopReason: "error", errorMessage: "fixture failure", answers: {} }),
		async () => { throw Error("fixture failure"); },
	]) {
		const saved = await run({ getModelOfType: async () => ({}), classify });
		assert.equal(saved.labels.length, 5);
		assert.ok(saved.labels.every(x => x.stopReason === "error" && x.error));
		assert.equal(saved.cost, 0);
	}
});

test("a missing model or failed catalog saves a skipped result", async () => {
	for (const getModelOfType of [async () => undefined, async () => { throw Error("fixture catalog"); }]) {
		const saved = await run({ getModelOfType });
		assert.match(saved.skipped, /Classifier unavailable/);
		assert.equal(saved.labels.length, 0);
		assert.equal(saved.jobs, 5);
	}
});

test("the $0.10 preflight budget skips calls for an oversized window", async () => {
	let calls = 0;
	const audit = { ...fixture, sessions: [{ ...fixture.sessions[0], reports: Array(300).fill("x".repeat(2000)) }] };
	const saved = await run({
		getModelOfType: async () => ({}),
		classify: async () => { calls++; },
	}, audit);
	assert.equal(calls, 0);
	assert.match(saved.skipped, /Preflight exceeds \$0.10/);
	assert.equal(saved.cost, 0);
});
