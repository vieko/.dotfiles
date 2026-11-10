import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

const WALL_MS = 240_000;
const KILL_GRACE_MS = 5_000;
const COST_CAP = 0.25;
const REPORT_BYTES = 20 * 1024;
const MAX_PARALLEL = 4;
const DEFAULT_MODEL = "anthropic/claude-haiku-5.5:low";

const SYSTEM_PROMPT = `You are a scout. Quickly investigate a codebase and return structured findings for another agent.
The reader has not seen the files you explore. Work read-only; never edit files.
Do not open credential files (.env*, auth.json, ~/.secrets, *.pem, key files); if the task seems to need one, report that instead.
Use grep and find to locate relevant code, then read key sections and trace dependencies as needed.
Cite path:line for every claim. Say "not found" instead of guessing.
Keep the report under about 600 words unless the task asks for more.
Include relevant files and line ranges, key code or behavior, connections, and where to start, as appropriate to the task.`;

type Usage = {
	input: number;
	output: number;
	cacheRead: number;
	cacheWrite: number;
	totalTokens: number;
	cost: { input: number; output: number; cacheRead: number; cacheWrite: number; total: number };
};
type Status = "queued" | "running" | "completed" | "failed" | "capped" | "timed out" | "aborted";
type Result = {
	model: string;
	status: Status;
	turns: number;
	durationMs: number;
	usage: Usage;
	text: string;
	error?: string;
};

const emptyUsage = (): Usage => ({
	input: 0,
	output: 0,
	cacheRead: 0,
	cacheWrite: 0,
	totalTokens: 0,
	cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
});

function addUsage(total: Usage, usage: Partial<Usage>) {
	for (const key of ["input", "output", "cacheRead", "cacheWrite", "totalTokens"] as const) {
		total[key] += usage[key] ?? 0;
	}
	for (const key of ["input", "output", "cacheRead", "cacheWrite", "total"] as const) {
		total.cost[key] += usage.cost?.[key] ?? 0;
	}
}

function clip(text: string): string {
	const buf = Buffer.from(text);
	if (buf.length <= REPORT_BYTES) return text;
	return buf.subarray(0, REPORT_BYTES - 32).toString("utf8").replace(/\uFFFD$/, "") + "\n[report truncated]";
}

// Match the bundled subagent's invocation for Node, Bun, and compiled Pi.
function getPiInvocation(args: string[]): { command: string; args: string[] } {
	const script = process.argv[1];
	const virtual = script && (script.startsWith("/$bunfs/root/") || /^[A-Za-z]:[\\/]~BUN[\\/]root[\\/]/.test(script));
	if (script && !virtual && existsSync(script)) return { command: process.execPath, args: [script, ...args] };
	if (!/^(node|bun)(\.exe)?$/.test(path.basename(process.execPath).toLowerCase())) {
		return { command: process.execPath, args };
	}
	return { command: "pi", args };
}

async function runChild(
	task: string,
	cwd: string,
	model: string,
	signal: AbortSignal | undefined,
	result: Result,
	update: () => void,
): Promise<void> {
	const start = Date.now();
	let dir: string | undefined;
	try {
		if (signal?.aborted) {
			result.status = "aborted";
			return;
		}
		dir = await mkdtemp(path.join(tmpdir(), "pi-scout-"));
		const taskPath = path.join(dir, "task.txt");
		const promptPath = path.join(dir, "system.txt");
		await Promise.all([
			writeFile(taskPath, task, { mode: 0o600 }),
			writeFile(promptPath, SYSTEM_PROMPT, { mode: 0o600 }),
		]);
		if (signal?.aborted) {
			result.status = "aborted";
			return;
		}
		const args = [
			"--mode", "json", "-p", "--no-session", "--provider", "vercel-ai-gateway", "--model", model,
			"--tools", "read,grep,find,ls", "--no-extensions", "--no-skills", "--no-mcp", "--no-prompt-templates",
			"--no-context-files", "--append-system-prompt", promptPath, `Read ${taskPath} and follow it.`,
		];
		result.status = "running";
		update();
		await new Promise<void>((resolve) => {
			const invocation = getPiInvocation(args);
			const proc = spawn(invocation.command, invocation.args, {
				cwd,
				env: { ...process.env, PI_COUNSEL: "off" },
				stdio: ["ignore", "pipe", "pipe"],
				shell: false,
			});
			let buffer = "";
			let stderr = "";
			let stop: Status | undefined;
			let killTimer: ReturnType<typeof setTimeout> | undefined;
			let stopReason: string | undefined;
			let messageError: string | undefined;
			let partialText = "";
			const terminate = (reason: Status) => {
				if (stop || proc.exitCode !== null || proc.signalCode !== null) return;
				stop = reason;
				proc.kill("SIGTERM");
				killTimer = setTimeout(() => proc.kill("SIGKILL"), KILL_GRACE_MS);
			};
			const timer = setTimeout(() => terminate("timed out"), WALL_MS);
			const abort = () => terminate("aborted");
			const line = (s: string) => {
				try {
					const event = JSON.parse(s);
					if (event.type === "message_start" && event.message?.role === "assistant") partialText = "";
					if (event.type === "message_update" && event.assistantMessageEvent?.type === "text_delta") {
						partialText += event.assistantMessageEvent.delta;
						result.text = partialText;
					}
					if (event.type !== "message_end" || event.message?.role !== "assistant") return;
					const m = event.message;
					result.turns++;
					if (m.usage) addUsage(result.usage, m.usage);
					const text = (m.content ?? [])
						.filter((c: { type: string }) => c.type === "text")
						.map((c: { text: string }) => c.text)
						.join("\n");
					if (text) result.text = text;
					stopReason = m.stopReason;
					messageError = m.errorMessage;
					// Usage arrives at message end, so the cap can overshoot by one turn.
					if (result.usage.cost.total > COST_CAP) terminate("capped");
					update();
				} catch {
					/* Ignore non-JSON output. */
				}
			};
			proc.stdout.on("data", (chunk) => {
				buffer += chunk.toString();
				const lines = buffer.split("\n");
				buffer = lines.pop() ?? "";
				for (const item of lines) line(item);
			});
			proc.stderr.on("data", (chunk) => {
				stderr = clip(stderr + chunk.toString());
			});
			let spawnError: string | undefined;
			proc.on("error", (err) => {
				spawnError = err.message;
			});
			proc.on("close", (code, terminationSignal) => {
				if (buffer.trim()) line(buffer);
				clearTimeout(timer);
				if (killTimer) clearTimeout(killTimer);
				signal?.removeEventListener("abort", abort);
				result.status = stop ?? (
					spawnError || code !== 0 || terminationSignal || stopReason === "error"
						? "failed"
						: stopReason === "aborted" ? "aborted" : "completed"
				);
				if (result.status !== "completed") {
					result.error = [
						spawnError,
						terminationSignal && `signal ${terminationSignal}`,
						code !== null && code !== 0 && `exit ${code}`,
						messageError,
						stderr.trim(),
					].filter(Boolean).join("\n") || undefined;
				}
				resolve();
			});
			if (signal?.aborted) abort();
			else signal?.addEventListener("abort", abort, { once: true });
		});
	} catch (err) {
		result.status = "failed";
		result.error = err instanceof Error ? err.message : String(err);
	} finally {
		if (dir) await rm(dir, { recursive: true, force: true });
		result.durationMs = Date.now() - start;
		update();
	}
}

export default function (pi: ExtensionAPI) {
	if (process.env.PI_SCOUT === "off") return;
	pi.registerTool({
		name: "scout",
		label: "scout",
		description:
			"Run read-only scouts in parallel and return cited reports. Use for gathering across several files, " +
			"locating behavior, cross-checking, or surveys when raw text is not needed. Give independent questions " +
			"as parallel tasks. Do not use for one or two known files, shell work (git, gh, tests), or edits. " +
			"Scouts cannot run commands. Reports are unreviewed claims: open cited lines before an edit depends on them.",
		promptSnippet: "Run read-only scouts in parallel for cited codebase reports",
		promptGuidelines: [
			"Use scout to gather across several files when raw text is not needed; " +
				"verify cited lines before an edit depends on its report.",
		],
		parameters: Type.Object({
			tasks: Type.Array(
				Type.Object({
					task: Type.String({
						description: "Self-contained instruction. The scout has not seen this conversation: " +
							"name the repo area, the question, and what the report must contain",
					}),
					cwd: Type.Optional(Type.String({
						description: "Directory the scout starts in, relative to the session cwd; default is the session cwd",
					})),
				}),
				{ minItems: 1, maxItems: 8, description: "1 to 8 independent questions; at most 4 run at a time" },
			),
		}),
		async execute(_id, params, signal, onUpdate, ctx) {
			const start = Date.now();
			const model = process.env.PI_SCOUT_MODEL || DEFAULT_MODEL;
			const results: Result[] = params.tasks.map(() => ({
				model, status: "queued", turns: 0, durationMs: 0, usage: emptyUsage(), text: "",
			}));
			const update = () => onUpdate?.({
				content: [{ type: "text", text: results.map((r, i) => `${i + 1}. ${r.status}`).join("\n") }],
				details: { children: results.map(({ text: _text, ...r }) => ({ ...r, cost: r.usage.cost.total })) },
			});
			let next = 0;
			const worker = async () => {
				while (next < params.tasks.length) {
					const i = next++;
					await runChild(
						params.tasks[i].task, path.resolve(ctx.cwd, params.tasks[i].cwd ?? "."),
						model, signal, results[i], update,
					);
				}
			};
			await Promise.all(Array.from({ length: Math.min(MAX_PARALLEL, params.tasks.length) }, worker));
			const usage = emptyUsage();
			for (const result of results) addUsage(usage, result.usage);
			const children = results.map(({ text: _text, ...r }) => ({ ...r, cost: r.usage.cost.total }));
			pi.appendEntry("scout", {
				taskCount: results.length,
				statuses: results.map((r) => r.status),
				totalCost: usage.cost.total,
				durationMs: Date.now() - start,
				model,
			});
			return {
				content: [{
					type: "text",
					text: results.map((r, i) => {
						const header = `${i + 1}. ${r.status} | ${r.turns} turns | ` +
							`$${r.usage.cost.total.toFixed(4)} | ${(r.durationMs / 1000).toFixed(1)}s`;
						const report = clip([r.text, r.error && `Error: ${r.error}`].filter(Boolean).join("\n") ||
							"(no assistant text)");
						return `${header}\n${report}`;
					}).join("\n\n"),
				}],
				details: { children },
				usage,
			};
		},
	});
}
