// Run: node --test ~/.dotfiles/pi/.pi/agent/extensions/destructive-guard/
import assert from "node:assert/strict";
import { test } from "node:test";
import { checkCommand, checkToolCall } from "./match.mjs";

const rule = (cmd) => checkCommand(cmd)?.rule ?? null;
const tier = (cmd) => checkCommand(cmd)?.tier ?? null;

test("catches gated commands in any argument order", () => {
	const cases = {
		"vercel env pull": "vercel-env-pull",
		"vercel env pull --yes .env.local": "vercel-env-pull",
		"cd apps/web && vercel env pull --environment=preview": "vercel-env-pull",
		"vercel --prod": "vercel-deploy",
		vercel: "vercel-deploy",
		"vercel deploy --prebuilt": "vercel-deploy",
		"npx vercel promote dpl_123": "vercel-deploy",
		"pnpm dlx vercel env pull": "vercel-env-pull",
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
		"bash -c 'vercel env pull'": "vercel-env-pull",
		"sh -lc \"git push origin main --force\"": "git-force-push",
		"FOO=1 sudo git push -f": "git-force-push",
		"timeout 60 pnpm db:migrate": "db-migrate",
		"/opt/homebrew/bin/git push --force": "git-force-push",
		"(cd x; vercel env pull)": "vercel-env-pull",
		"echo $(vercel env pull)": "vercel-env-pull",
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
		"vercel logs dpl_1",
		"vercel ls",
		"pnpm db:generate",
		"pnpm drizzle-kit generate",
		"prisma migrate dev --create-only",
		"pnpm install",
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
	assert.equal(tier("vercel env pull"), "never");
	assert.equal(tier("git push -f"), "confirm");
	assert.equal(tier("git push -f; vercel env pull"), "never");
});

test("tool calls from both harnesses", () => {
	assert.equal(checkToolCall("Bash", { command: "vercel env pull" })?.rule, "vercel-env-pull");
	assert.equal(checkToolCall("read", { path: "~/.pi/agent/auth.json" })?.rule, "secret-read");
	assert.equal(checkToolCall("Read", { file_path: "/Users/x/.ssh/id_rsa" })?.rule, "secret-read");
	assert.equal(checkToolCall("read", { path: ".env.local" }), null);
	assert.equal(checkToolCall("write", { path: "apps/web/.env.local" })?.rule, "env-overwrite");
	assert.equal(checkToolCall("Edit", { file_path: "/r/.env" })?.rule, "env-overwrite");
	assert.equal(checkToolCall("write", { path: ".env.example" }), null);
	assert.equal(checkToolCall("edit", { path: "src/env.ts" }), null);
});
