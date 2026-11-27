// Run: node --test ~/.dotfiles/pi/.pi/agent/extensions/destructive-guard/*.test.mjs
import assert from "node:assert/strict";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { decide, hashCall, list, read, request, waitFor } from "./approvals.mjs";

const fresh = () => mkdtempSync(join(tmpdir(), "approvals-"));
const call = { tool: "bash", input: { command: "git push origin main" }, rule: "inbox-write", reason: "git push publishes commits" };

test("a request is pending until the user answers it once", () => {
	const dir = fresh();
	const req = request({ ...call, dir, address: "s-0123456789ab", cwd: "/r" });
	assert.match(req.id, /^[a-z0-9]{12}$/);
	assert.equal(read(req.id, dir).status, "pending");
	assert.equal(list({ dir }).length, 1);
	assert.equal(decide(req.id, "approved", "cli", { dir }).ok, true);
	const again = decide(req.id, "denied", "cli", { dir });
	assert.equal(again.ok, false);
	assert.equal(again.code, 409);
	assert.equal(list({ dir }).length, 0);
	assert.equal(list({ dir, all: true })[0].status, "approved");
});

test("expired requests cannot be approved", () => {
	const dir = fresh();
	const req = request({ ...call, dir, waitMs: 1000, now: Date.now() - 5000 });
	const r = decide(req.id, "approved", "cli", { dir });
	assert.equal(r.ok, false);
	assert.match(r.error, /expired/);
});

test("bad ids and decisions are refused", () => {
	const dir = fresh();
	assert.equal(decide("../etc/passwd", "approved", "cli", { dir }).code, 404);
	assert.equal(decide("abcdefabcdef", "yes", "cli", { dir }).code, 400);
});

test("waitFor resolves with the answer, and only for the held call", async () => {
	const dir = fresh();
	const req = request({ ...call, dir });
	setTimeout(() => decide(req.id, "approved", "cli", { dir }), 30);
	assert.equal(await waitFor(req.id, req.hash, { dir, pollMs: 10 }), "approved");

	const other = request({ ...call, dir });
	decide(other.id, "approved", "cli", { dir });
	const wrong = hashCall("bash", { command: "git push --force" });
	assert.equal(await waitFor(other.id, wrong, { dir, pollMs: 10 }), "denied");

	const denied = request({ ...call, dir });
	setTimeout(() => decide(denied.id, "denied", "cli", { dir }), 30);
	assert.equal(await waitFor(denied.id, denied.hash, { dir, pollMs: 10 }), "denied");
});

test("waitFor stops on abort and on expiry", async () => {
	const dir = fresh();
	const ac = new AbortController();
	const req = request({ ...call, dir });
	setTimeout(() => ac.abort(), 30);
	assert.equal(await waitFor(req.id, req.hash, { dir, pollMs: 10, signal: ac.signal }), "aborted");
	const short = request({ ...call, dir, waitMs: 20 });
	assert.equal(await waitFor(short.id, short.hash, { dir, pollMs: 10 }), "expired");
});
