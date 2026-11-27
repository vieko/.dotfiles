// Run: node --test ~/.dotfiles/pi/.pi/agent/extensions/destructive-guard/*.test.mjs
import assert from "node:assert/strict";
import { test } from "node:test";
import { checkCommand, checkToolCall } from "./match.mjs";

const rule = (cmd) => checkCommand(cmd)?.rule ?? null;
const tier = (cmd) => checkCommand(cmd)?.tier ?? null;

test("catches gated commands in any argument order", () => {
	const cases = {
		"vercel --prod": "vercel-deploy",
		vercel: "vercel-deploy",
		"vercel deploy --prebuilt": "vercel-deploy",
		"npx vercel promote dpl_123": "vercel-deploy",
		"pnpm dlx vercel deploy": "vercel-deploy",
		"npx vercel": "vercel-deploy",
		"bun x vercel --prod": "vercel-deploy",
		"pnpm prisma migrate deploy": "db-migrate",
		"git push --force": "git-force-push",
		"git push origin x --force": "git-force-push",
		"git -C ~/dev/gtm push -f": "git-force-push",
		"git push -uf origin main": "git-force-push",
		"git push --force-with-lease origin feat": "git-force-push",
		"git push origin +main": "git-force-push",
		"git reset --hard origin/main": "git-reset-hard",
		"git clean -fd": "git-clean",
		"pnpm db:migrate": "db-migrate",
		"pnpm --filter @repo/db db:push": "db-migrate",
		"npm run db:migrate": "db-migrate",
		"npx drizzle-kit push": "db-migrate",
		"pnpm exec drizzle-kit migrate": "db-migrate",
		"pnpm prisma db push": "db-migrate",
		"prisma migrate dev": "db-migrate",
		"npm publish": "publish",
		"pnpm -r publish --access public": "publish",
		"bun publish": "publish",
		"cat ~/.pi/agent/auth.json": "secret-read",
		"cat $HOME/.ssh/id_ed25519": "secret-read",
		"source ~/.secrets": "secret-read",
		"echo FOO=1 > .env.local": "env-overwrite",
		"rm -rf ~": "rm-root",
		"rm -rf /": "rm-root",
		"bash -c 'vercel --prod'": "vercel-deploy",
		"sh -lc \"git push origin main --force\"": "git-force-push",
		"FOO=1 sudo git push -f": "git-force-push",
		"timeout 60 pnpm db:migrate": "db-migrate",
		"/opt/homebrew/bin/git push --force": "git-force-push",
		"(cd x; vercel deploy)": "vercel-deploy",
		"echo $(git push -f)": "git-force-push",
		"git status && git push --force; echo done": "git-force-push",
	};
	for (const [cmd, want] of Object.entries(cases)) assert.equal(rule(cmd), want, cmd);
});

test("passes normal work and commands that only mention gated words", () => {
	const ok = [
		"git push",
		"git push -u origin feat/x",
		"git push origin --delete feat/x",
		"git reset --soft HEAD~1",
		"git commit -m 'never run vercel env pull or git push --force'",
		'git commit -m "docs: forbid vercel env pull"',
		"echo 'pnpm db:migrate'",
		"grep -rn 'vercel env pull' AGENTS.md",
		"rg -n \"push --force\" docs",
		"vercel env ls",
		"vercel env pull",
		"vercel env pull --yes .env.local",
		"cd apps/web && vercel env pull --environment=preview",
		"vercel pull --yes",
		"npx vercel env pull",
		"vercel logs dpl_1",
		"vercel ls",
		"pnpm db:generate",
		"pnpm drizzle-kit generate",
		"prisma migrate dev --create-only",
		"pnpm install",
		"pnpm add vercel",
		"npm i -g vercel",
		"npm install vercel@latest",
		"pnpm add -D prisma drizzle-kit",
		"vercel switch",
		"vercel project ls",
		"vercel blob put x",
		"vercel link",
		"vercel whoami",
		"git push --follow-tags",
		"pnpm db:branch:create x",
		"pnpm --filter @repo/db run db:branch:delete x",
		"pnpm deploy --filter app out",
		"source .env.local && pnpm tsx scripts/x.ts",
		"cat .env.example",
		"ls ~/.ssh",
		"cat ~/.ssh/id_ed25519.pub",
		"cat ~/.ssh/config",
		"rm -rf node_modules dist",
		"rm -rf /tmp/foo/bar",
		"echo hi >> .env.example",
		"pi auth print-api-key vercel-ai-gateway",
	];
	for (const cmd of ok) assert.equal(rule(cmd), null, cmd);
});

test("heredoc bodies are data", () => {
	const notes = [
		"cat > ~/scratch/notes.md <<'EOF'",
		"- allow list includes `vercel env:*` (covers `vercel env pull`), `Bash(git:*)` (covers push --force)",
		"vercel env pull",
		"git push --force",
		"EOF",
		"echo ok",
	].join("\n");
	assert.equal(rule(notes), null);
	assert.equal(rule(`${notes}\ngit push -f`), "git-force-push");
});

test("tiers", () => {
	assert.equal(tier("rm -rf ~"), "never");
	assert.equal(tier("git push -f"), "confirm");
	assert.equal(tier("git push -f; rm -rf /"), "never");
});

test("tool calls from both harnesses", () => {
	assert.equal(checkToolCall("Bash", { command: "vercel env pull" }), null);
	assert.equal(checkToolCall("Bash", { command: "vercel --prod" })?.rule, "vercel-deploy");
	assert.equal(checkToolCall("read", { path: "~/.pi/agent/auth.json" })?.rule, "secret-read");
	assert.equal(checkToolCall("Read", { file_path: "/Users/x/.ssh/id_rsa" })?.rule, "secret-read");
	assert.equal(checkToolCall("read", { path: ".env.local" }), null);
	assert.equal(checkToolCall("write", { path: "apps/web/.env.local" })?.rule, "env-overwrite");
	assert.equal(checkToolCall("Edit", { file_path: "/r/.env" })?.rule, "env-overwrite");
	assert.equal(checkToolCall("write", { path: ".env.example" }), null);
	assert.equal(checkToolCall("edit", { path: "src/env.ts" }), null);
});

test("database writer scripts ask in every form", () => {
	const asks = [
		".claude/scripts/matchups-push-run.sh /tmp/t.json",
		".claude/scripts/matchups-push-run.sh /tmp/t.json --dry-run",
		"bash .claude/scripts/db-run.sh migrate",
		"bash -x /home/v/dev/battlemox/.claude/scripts/db-run.sh migrate",
		"/home/v/dev/battlemox/.claude/scripts/db-run-dev.sh import",
		"cd .claude/scripts && ./db-run.sh pull",
		"gh pr merge 1 --squash && ~/dev/battlemox/.claude/scripts/matchups-push-run.sh t.json",
		"timeout 60 sh .claude/scripts/db-run.sh migrate --dry-run",
		"source .claude/scripts/db-run.sh",
		"bash -c '.claude/scripts/db-run.sh migrate'",
	];
	for (const c of asks) assert.equal(rule(c), "writer-script", c);
	assert.equal(tier(asks[0]), "confirm");
	const passes = [
		".claude/scripts/records-run.sh feedback --status new",
		"bash .claude/scripts/merge-queue.sh 620",
		".claude/scripts/prune-run.sh",
		"cat .claude/scripts/db-run.sh",
		"git log -- .claude/scripts/matchups-push-run.sh",
		"echo 'run db-run.sh migrate later'",
		"bash -c 'echo hi'",
	];
	for (const c of passes) assert.equal(rule(c), null, c);
});

test("agents cannot answer approval requests", () => {
	const self = [
		"~/.scripts/approvals approve abcdef012345",
		"approvals deny abcdef012345",
		"curl -X POST http://127.0.0.1:5858/approvals/abcdef012345/approve",
		"curl -s -X POST -H 'Origin: http://localhost:3000' \"http://localhost:3000/api/approvals/abcdef012345/approve\"",
		"node -e 'x' > ~/.local/state/approvals/abcdef012345.json",
		"jq '.status=\"approved\"' ~/.local/state/approvals/a.json > /tmp/x && mv /tmp/x ~/.local/state/approvals/a.json",
		"rm ~/.local/state/approvals/a.json",
	];
	for (const c of self) assert.equal(rule(c), "approval-self", c);
	assert.equal(tier(self[0]), "never");
	const ok = ["approvals list", "approvals show abcdef012345", "ls ~/.local/state/approvals", "cat ~/.local/state/approvals/a.json | jq .status"];
	for (const c of ok) assert.equal(rule(c), null, c);
	assert.equal(checkToolCall("write", { path: `${process.env.HOME}/.local/state/approvals/a.json` })?.rule, "approval-self");
	assert.equal(checkToolCall("read", { path: "~/.local/state/approvals/a.json" }), null);
});

test("the inbox flag makes pushes and PR writes ask", () => {
	const inbox = { inbox: true };
	assert.equal(checkCommand("git push origin vieko/x"), null);
	assert.equal(checkCommand("gh pr create --fill"), null);
	assert.equal(checkCommand("git push -u origin vieko/x", inbox)?.rule, "inbox-write");
	assert.equal(checkCommand("cd /r && gh pr create --title t --body-file b.md", inbox)?.rule, "inbox-write");
	assert.equal(checkCommand("gh pr merge 12 --squash", inbox)?.rule, "inbox-write");
	assert.equal(checkCommand("git push --force", inbox)?.rule, "git-force-push");
	assert.equal(checkCommand("gh pr view 12", inbox), null);
	assert.equal(checkToolCall("bash", { command: "git push" }, inbox)?.rule, "inbox-write");
});
