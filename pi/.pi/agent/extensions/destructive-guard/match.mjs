/**
 * Destructive-command matcher shared by the Pi extension (index.ts) and the
 * Claude Code PreToolUse hook (claude-hook.mjs). One rule set, two harnesses.
 *
 * This is an accident guard, not a security boundary: it catches an agent
 * running a gated command by mistake. A determined or injected command can
 * still get past it (an alias, a script file, base64). The boundary is the
 * sandbox lane. Rules follow the "Destructive command guard" in
 * ~/.pi/agent/AGENTS.md.
 *
 * Tiers:
 *   never    always blocked; the user runs it by hand
 *   confirm  needs the user's yes in the session; blocked when nobody can answer
 *
 * Matching looks at command position only, so a commit message, an echo, or a
 * heredoc body that mentions `vercel env pull` does not match.
 */

import { homedir } from "node:os";

/** @typedef {{ tier: "never" | "confirm"; rule: string; reason: string }} Hit */

const HOME = homedir();

// Wrappers that run the next word as the command.
const WRAPPERS = new Set(["sudo", "env", "command", "exec", "time", "nohup", "nice", "caffeinate"]);
const SHELLS = new Set(["bash", "sh", "zsh", "dash"]);
const PKG = new Set(["npm", "pnpm", "yarn", "bun", "npx", "bunx", "turbo"]);

// Private keys and credential stores. Public keys and ssh config are fine.
const SECRET_PATHS = [
	/(^|\/)\.ssh\/id_[^/]*$(?<!\.pub)/,
	/(^|\/)\.ssh\/[^/]*\.pem$/,
	/(^|\/)\.secrets(\/|$)/,
	/(^|\/)\.pi\/agent\/auth\.json$/,
	/(^|\/)\.aws\/credentials$/,
	/(^|\/)\.config\/gh\/hosts\.yml$/,
];

const ENV_FILE = /(^|\/)\.env(\.[A-Za-z0-9_-]+)*$/;
const ENV_TEMPLATE = /\.(example|sample|template|defaults)$/;

/** Expand ~ and $HOME so path rules see absolute paths. */
function expandHome(p) {
	return p.replace(/^~(?=\/|$)/, HOME).replace(/^\$\{?HOME\}?(?=\/|$)/, HOME);
}

export function isSecretPath(p) {
	const abs = expandHome(String(p).trim());
	return SECRET_PATHS.some((re) => re.test(abs));
}

export function isEnvFile(p) {
	const s = String(p).trim();
	return ENV_FILE.test(s) && !ENV_TEMPLATE.test(s);
}

/** Drop heredoc bodies: they are data, not commands. */
function stripHeredocs(cmd) {
	const lines = cmd.split("\n");
	const out = [];
	let end = null;
	for (const line of lines) {
		if (end !== null) {
			if (line.replace(/^\t+/, "") === end) end = null;
			continue;
		}
		out.push(line);
		const m = /<<-?\s*(['"]?)([A-Za-z_][A-Za-z0-9_]*)\1/.exec(line);
		if (m) end = m[2];
	}
	return out.join("\n");
}

/**
 * Pull out the script of `bash -c '...'` and `eval "..."` so it is checked as
 * a command, then blank every quoted string so its words cannot match.
 */
function unquote(cmd) {
	const inner = [];
	const shellC = /\b(?:bash|sh|zsh|dash)\s+-[a-z]*c\s+(['"])((?:\\.|(?!\1).)*)\1/gs;
	const evalRe = /\beval\s+(['"])((?:\\.|(?!\1).)*)\1/gs;
	for (const re of [shellC, evalRe]) for (const m of cmd.matchAll(re)) inner.push(m[2]);
	const blanked = cmd.replace(/'[^']*'/g, "''").replace(/"(?:\\.|[^"\\])*"/g, '""');
	return { blanked, inner };
}

/** Split into simple commands at operators, newlines, and subshell openers. */
function segments(cmd) {
	return cmd
		.split(/\|\||&&|[;|&\n`]|\$\(|\(|\)|\{|\}|\bthen\b|\bdo\b|\belse\b/)
		.map((s) => s.trim())
		.filter(Boolean);
}

/** Words of a simple command with env assignments and wrappers removed. */
function words(seg) {
	let w = seg.split(/\s+/).filter(Boolean);
	for (;;) {
		if (w.length && /^[A-Za-z_][A-Za-z0-9_]*=/.test(w[0])) w = w.slice(1);
		else if (w.length && WRAPPERS.has(w[0])) w = w.slice(1);
		else if (w[0] === "timeout" || w[0] === "gtimeout") w = w.slice(/^\d/.test(w[1] ?? "") ? 2 : 1);
		else if (w[0] === "xargs") {
			let i = 1;
			while (i < w.length && w[i].startsWith("-")) i += /^-[nILPsEd]$/.test(w[i]) ? 2 : 1;
			w = w.slice(i);
		}
		else break;
	}
	// A path to a binary counts as the binary: /opt/homebrew/bin/git -> git.
	if (w.length) w[0] = w[0].replace(/^.*\//, "");
	return w;
}

/** git subcommand and its arguments, skipping global options like -C <path>. */
function gitArgs(w) {
	let i = 1;
	while (i < w.length && w[i].startsWith("-")) {
		if (["-C", "-c", "--git-dir", "--work-tree", "--namespace"].includes(w[i])) i += 2;
		else i += 1;
	}
	return { sub: w[i], args: w.slice(i + 1) };
}

/** The first word after `pkg`, skipping flags and their values. */
function pkgScripts(w) {
	return w.slice(1).filter((x) => !x.startsWith("-"));
}

/** @returns {Hit | null} */
function checkWords(w, raw) {
	if (!w.length) return null;
	const [prog] = w;

	if (prog === "git") {
		const { sub, args } = gitArgs(w);
		if (sub === "push") {
			const force = args.some(
				(a) => a === "--force" || a.startsWith("--force-with-lease") || a === "--mirror" || /^-[a-zA-Z]*f[a-zA-Z]*$/.test(a) || /^\+[^\s]/.test(a),
			);
			if (force) return { tier: "confirm", rule: "git-force-push", reason: "force-push rewrites remote history" };
		}
		if (sub === "reset" && args.includes("--hard"))
			return { tier: "confirm", rule: "git-reset-hard", reason: "git reset --hard discards uncommitted work" };
		if (sub === "clean" && args.some((a) => /^-[a-zA-Z]*f/.test(a) || a === "--force"))
			return { tier: "confirm", rule: "git-clean", reason: "git clean -f deletes untracked files" };
		return null;
	}

	if (prog === "vercel" || prog === "vc") {
		const pos = w.slice(1).filter((x) => !x.startsWith("-"));
		const sub = pos[0];
		if (sub === "env" && pos[1] === "pull")
			return { tier: "never", rule: "vercel-env-pull", reason: "vercel env pull overwrites .env.local; forbidden on this machine (use `vercel env ls`)" };
		if (sub === "pull")
			return { tier: "confirm", rule: "vercel-pull", reason: "vercel pull writes .vercel/.env files over local ones" };
		const deploys = new Set(["deploy", "promote", "rollback", "redeploy"]);
		if (sub === undefined || deploys.has(sub) || w.includes("--prod") || w.includes("--production"))
			return { tier: "confirm", rule: "vercel-deploy", reason: "this deploys or changes a live deployment" };
		return null;
	}

	if (PKG.has(prog)) {
		const s = pkgScripts(w);
		if (s.includes("publish") && prog !== "npx" && prog !== "turbo")
			return { tier: "confirm", rule: "publish", reason: "package publish is public and permanent" };
		if (s.some((x) => /^db:(migrate|push|reset|drop)(\b|:|$)/.test(x)))
			return { tier: "confirm", rule: "db-migrate", reason: "applies a schema change to whichever DB DATABASE_URL points at" };
		if (prog === "pnpm" && s[0] === "deploy") return null; // pnpm deploy copies a workspace package locally
		// npx drizzle-kit push / pnpm exec prisma db push / npx vercel: check the tool after the runner.
		const at = w.findIndex((x) => ["drizzle-kit", "prisma", "changeset", "vercel", "vc"].includes(x));
		if (at > 0) return checkWords(w.slice(at), raw);
		return null;
	}

	if (prog === "drizzle-kit") {
		const sub = w.slice(1).find((x) => !x.startsWith("-"));
		if (sub === "push" || sub === "migrate" || sub === "drop")
			return { tier: "confirm", rule: "db-migrate", reason: `drizzle-kit ${sub} changes a live database schema` };
		return null;
	}

	if (prog === "prisma") {
		const pos = w.slice(1).filter((x) => !x.startsWith("-"));
		if (pos[0] === "db" && pos[1] === "push") return { tier: "confirm", rule: "db-migrate", reason: "prisma db push changes a live schema" };
		if (pos[0] === "migrate" && ["deploy", "reset"].includes(pos[1]))
			return { tier: "confirm", rule: "db-migrate", reason: `prisma migrate ${pos[1]} changes a live schema` };
		if (pos[0] === "migrate" && pos[1] === "dev" && !w.includes("--create-only"))
			return { tier: "confirm", rule: "db-migrate", reason: "prisma migrate dev applies migrations (add --create-only to only write the file)" };
		return null;
	}

	if (prog === "changeset" && w[1] === "publish")
		return { tier: "confirm", rule: "publish", reason: "package publish is public and permanent" };

	if (prog === "rm" && w.some((a) => /^-[a-zA-Z]*r/.test(a) || a === "--recursive")) {
		const targets = w.slice(1).filter((a) => !a.startsWith("-")).map(expandHome);
		if (targets.some((t) => t === "/" || t === HOME || t === `${HOME}/` || t === "~" || /^\/[^/]*\/?$/.test(t) || t === "*"))
			return { tier: "never", rule: "rm-root", reason: "recursive delete of /, a top-level directory, or $HOME" };
		return null;
	}

	// Reading a credential file through the shell. ls/stat/test only look.
	if (!["ls", "stat", "test", "[", "chmod", "file"].includes(prog)) {
		const secret = w.slice(1).find((a) => isSecretPath(a.replace(/^[<>]+/, "")));
		if (secret) return { tier: "confirm", rule: "secret-read", reason: `${secret} is a credential; its contents would land in the transcript` };
	}

	// Overwriting an env file by redirect: > .env.local
	const m = /(?:^|[^>])>\s*([^\s;&|]+)/.exec(raw);
	if (m && isEnvFile(m[1])) return { tier: "confirm", rule: "env-overwrite", reason: `this overwrites ${m[1]}` };

	return null;
}

/**
 * Check a shell command string.
 * @param {string} command
 * @returns {Hit | null}
 */
export function checkCommand(command, depth = 0) {
	if (typeof command !== "string" || !command.trim() || depth > 3) return null;
	const { blanked, inner } = unquote(stripHeredocs(command));
	/** @type {Hit | null} */
	let best = null;
	for (const seg of segments(blanked)) {
		const w = words(seg);
		if (SHELLS.has(w[0])) continue; // its -c script is checked via `inner`
		const hit = checkWords(w, seg);
		if (hit && (!best || hit.tier === "never")) best = hit;
		if (best?.tier === "never") return best;
	}
	for (const s of inner) {
		const hit = checkCommand(s, depth + 1);
		if (hit && (!best || hit.tier === "never")) best = hit;
	}
	return best;
}

/**
 * Check a tool call by tool name. Names are lowercased so Pi (`bash`, `read`)
 * and Claude Code (`Bash`, `Read`) share one switch.
 * @param {string} tool
 * @param {Record<string, unknown>} input
 * @returns {Hit | null}
 */
export function checkToolCall(tool, input) {
	const t = String(tool).toLowerCase();
	if (t === "bash") return checkCommand(String(input?.command ?? ""));
	const path = String(input?.path ?? input?.file_path ?? "");
	if (!path) return null;
	if (t === "read" || t === "grep") {
		if (isSecretPath(path)) return { tier: "confirm", rule: "secret-read", reason: `${path} is a credential; its contents would land in the transcript` };
		return null;
	}
	if (t === "write" || t === "edit" || t === "multiedit") {
		if (isEnvFile(path)) return { tier: "confirm", rule: "env-overwrite", reason: `this rewrites ${path}, which may hold injected secrets` };
		if (isSecretPath(path)) return { tier: "confirm", rule: "secret-write", reason: `${path} is a credential file` };
	}
	return null;
}
