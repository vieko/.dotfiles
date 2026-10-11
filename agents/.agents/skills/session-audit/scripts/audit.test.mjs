#!/usr/bin/env node
// Deterministic integration checks with an isolated session directory.
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import test from "node:test";

const home = mkdtempSync(join(tmpdir(), "session-audit-test-"));
const sessionsDir = join(home, ".pi/agent/sessions/--fixture--");
mkdirSync(sessionsDir, { recursive: true });
const freeze = join(home, "freeze.cjs");
writeFileSync(freeze, "Date.now = () => Date.parse('2026-10-11T16:00:00Z');\n");
const script = fileURLToPath(new URL("./audit.mjs", import.meta.url));
const entry = (id, type, fields, timestamp = "2026-10-10T16:00:00Z") => ({ id, type, timestamp, ...fields });
const user = (id, text, timestamp) => entry(id, "message", {
	message: { role: "user", content: [{ type: "text", text }] },
}, timestamp);
const assistant = (id) => entry(id, "message", { message: {
	role: "assistant", model: "fixture", content: [], stopReason: "stop",
	usage: { input: 10, cacheRead: 0, cacheWrite: 0, output: 1,
		cost: { input: 1, output: 0, cacheRead: 0, cacheWrite: 0, total: 1 } },
} });
const report = "Message from pi session worker:\n\nCompleted the task.\nVerification: node --test passes.\nDeviations: none.\n" + "x".repeat(2200);
const first = user("u1", "  one\n\tlookup  " + "a".repeat(400), "2026-10-01T16:00:00Z");
const received = entry("r1", "custom_message", { customType: "pi-post", content: report });
const rows = [first, user("u2", "second prompt"), user("u3", "third prompt"), received,
	entry("r2", "custom_message", { customType: "pi-post", content: [
		{ type: "text", text: "Message from pi session reviewer:\nCompleted review. Verified check: PASS." },
	] }),
	entry("r3", "custom_message", { customType: "other", content: report }),
	entry("r4", "custom_message", { customType: "pi-post", content: "Message from process: not a session" }),
	entry("t1", "message", { message: { role: "toolResult", content: [{ type: "text", text: report }] } }),
	entry("r5", "custom_message", { customType: "pi-post", content: "Message from pi session fam-test:\nAck: verification passes; report back when done." }),
	entry("r6", "custom_message", { customType: "pi-post", content: "Message from pi session another:\nBlocked: command fails with ENOENT." }),
	entry("r7", "custom_message", { customType: "pi-post", content: "Message from pi session fam-test:\nVerification: node --test PASS. Deviations: none." }),
	entry("r8", "custom_message", { customType: "pi-post", content: "Message from pi session fam-test:\nPlease implement the task.\nCompleted should head your report." }),
	entry("r9", "custom_message", { customType: "pi-post", content: "Message from pi session fam-test:\nStep 2 implemented; checks in progress. Commit pushed." }),
	entry("r10", "custom_message", { customType: "pi-post", content: "Message from pi session worker:\nanvil review, relayed from user.\nReport back with the completed changes." }),
	entry("r11", "custom_message", { customType: "pi-post", content: "Message from pi session worker:\nThe previous task is complete.\nNext task: implement a change." }),
	entry("r12", "custom_message", { customType: "pi-post", content: "Message from pi session worker:\nGTMENG-12 follow-up complete; committed locally." }),
	entry("r13", "custom_message", { customType: "pi-post", content: "Message from pi session worker:\nREPORT: test audit lane -- DONE.\nVerification: ledger parsed." }),
	assistant("a1")];
writeFileSync(join(sessionsDir, "2026-10-10T16-00-parent.jsonl"), rows.map(x => JSON.stringify(x)).join("\n"));
// A fork inherits entries, but its sample must retain the original opener.
writeFileSync(join(sessionsDir, "2026-10-11T16-00-child.jsonl"), [first, received, user("u4", "fork follow-up"), assistant("a2")].map(x => JSON.stringify(x)).join("\n"));
let runNumber = 0;
const run = (extra = []) => {
	const outputPath = join(home, `output-${runNumber++}.json`);
	const result = spawnSync(process.execPath, ["--require", freeze, script, "--since", "7d", "--json", outputPath, ...extra], {
		encoding: "utf8", env: { ...process.env, HOME: home },
	});
	return { ...result, jsonText: result.status === 0 ? readFileSync(outputPath, "utf8") : null };
};

test("prompt extraction changes only opted-in JSON session fields", () => {
	const plain = run();
	const sampled = run(["--prompts", "2"]);
	assert.equal(plain.status, 0, plain.stderr);
	assert.equal(sampled.status, 0, sampled.stderr);
	assert.equal(plain.stdout, sampled.stdout);
	const data = JSON.parse(sampled.jsonText);
	assert.equal(data.sessions.length, 2);
	const [parent, child] = data.sessions;
	assert.equal(parent.prompts.length, 2);
	assert.equal(parent.prompts[0].length, 300);
	assert.ok(parent.prompts[0].startsWith(" one lookup "));
	assert.equal(parent.prompts[1], "second prompt");
	assert.deepEqual(child.prompts, [parent.prompts[0], "fork follow-up"]);
	assert.deepEqual(parent.reports, [report.slice(0, 2000), "Message from pi session reviewer:\nCompleted review. Verified check: PASS.",
		"Message from pi session another:\nBlocked: command fails with ENOENT.",
		"Message from pi session fam-test:\nVerification: node --test PASS. Deviations: none.",
		"Message from pi session worker:\nGTMENG-12 follow-up complete; committed locally.",
		"Message from pi session worker:\nREPORT: test audit lane -- DONE.\nVerification: ledger parsed."]);
	assert.deepEqual(child.reports, [report.slice(0, 2000)]);
	for (const s of data.sessions) { delete s.prompts; delete s.reports; }
	assert.equal(JSON.stringify(data, null, 1), plain.jsonText);
});

test("invalid prompt counts fail before auditing", () => {
	for (const value of ["0", "-1", "1.5", "no", "Infinity"]) {
		const result = run(["--prompts", value]);
		assert.notEqual(result.status, 0);
		assert.match(result.stderr, /expected a positive integer/);
	}
	assert.notEqual(run(["--prompts"]).status, 0);
});
