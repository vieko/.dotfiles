// Codemode script. Set window, or supply inputPath/outputPath overrides.
const window = "wk41-v2";
const base = `${(await tools.bash({command: 'printf %s "$HOME"'})).output}/scratch/data/audit-${window}`;
const inputPath = `${base}-labels-input.json`;
const outputPath = `${base}-labels.json`;
const rubric = JSON.parse(await tools.read({path: "~/.agents/skills/session-audit/references/luna-rubric.json"}));
const questionsById = rubric.questions;
const chunks = [];
for (let offset = 1; ; ) {
  const chunk = await tools.read({path: inputPath, offset, limit: 100});
  const more = chunk.match(/\n\n\[(\d+) more lines in file\. Use offset=(\d+) to continue\.\]$/);
  chunks.push(more ? chunk.slice(0, more.index) : chunk);
  if (!more) break;
  offset = Number(more[2]);
}
const audit = JSON.parse(chunks.join("\n"));
const jobs = [];
for (const [sessionIndex, s] of audit.sessions.entries()) {
  if (s.prompts?.[0]?.trim()) jobs.push({
    sessionIndex, dir: s.dir, file: s.file, kind: "session",
    state: {prompts: [s.prompts[0]]}, questions: {intent: questionsById.intent},
  });
  for (const [reportIndex, report] of (s.reports ?? []).entries()) jobs.push({
    sessionIndex, reportIndex, dir: s.dir, file: s.file, kind: "report",
    state: {report}, questions: {
      has_verification: questionsById.has_verification, lists_deviations: questionsById.lists_deviations,
    },
  });
}
const estimatedCost = jobs.reduce((n, j) => n + JSON.stringify({state: j.state, questions: j.questions}).length + 4000, 0) * 0.10 / 1e6;
const labels = [];
let cost = 0;
let skipped = null;
let model;
try {
  model = await models.getModelOfType("classifier", "vercel-ai-gateway", "openai/gpt-6-luna-decisions");
} catch (error) { skipped = `Classifier unavailable: ${String(error)}`; }
if (!model) skipped ??= "Classifier unavailable";
else if (estimatedCost >= 0.10) skipped = "Preflight exceeds $0.10; use a smaller window";
else for (let i = 0; i < jobs.length; i += 4) {
  if (cost >= 0.09) { skipped = "Budget guard stopped remaining calls"; break; }
  const batch = await Promise.allSettled(jobs.slice(i, i + 4).map(async (j) => {
    const r = await models.classify(model, {state: j.state, questions: j.questions});
    return {sessionIndex: j.sessionIndex, reportIndex: j.reportIndex, dir: j.dir,
      file: j.file, kind: j.kind, stopReason: r.stopReason,
      error: r.errorMessage, answers: r.stopReason === "stop" ? r.answers : {}, usage: r.usage};
  }));
  for (const [k, r] of batch.entries()) {
    const j = jobs[i + k];
    const row = r.status === "fulfilled" ? r.value : {
      sessionIndex: j.sessionIndex, reportIndex: j.reportIndex, dir: j.dir,
      file: j.file, kind: j.kind, stopReason: "error", error: String(r.reason), answers: {},
    };
    cost += row.usage?.cost?.total ?? 0;
    labels.push(row);
  }
}
await tools.write({path: outputPath, content: JSON.stringify({
  rubricVersion: rubric.version, rubric, provider: "vercel-ai-gateway", model: "openai/gpt-6-luna-decisions",
  inputPath, since: audit.since, until: audit.until, budget: 0.10,
  estimatedCost, cost, jobs: jobs.length, skipped, labels,
}, null, 2)});
text({outputPath, labelled: labels.filter(x => x.stopReason === "stop").length,
  errors: labels.filter(x => x.stopReason !== "stop").length, skipped, cost});
