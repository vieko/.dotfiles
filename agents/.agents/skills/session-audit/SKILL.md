---
name: session-audit
description: Audit recent pi sessions for cost, prompt-cache behavior, context size, tool failures, constructs (golems/familiars), and recurring prompt patterns, then turn the numbers into footguns, opportunities, and gaps. Use whenever the user asks to assess, audit, or review the week's (or any window's) sessions, "what did we spend", "anything we should look into", "new patterns", or wants a recurring session health check. Runs a deterministic script over ~/.pi/agent/sessions and interprets the report.
---

# session-audit

Numbers come from the script; judgment comes from you. Never estimate what the
script can count.

## Run

```bash
node ~/.agents/skills/session-audit/scripts/audit.mjs --since 7d            # default window
node ~/.agents/skills/session-audit/scripts/audit.mjs --since 2026-08-31 --until 2026-09-06 --json ~/scratch/data/audit-<week>.json
anvil status --all --since 7d        # golem verdicts + USD (anvil >= 0.3.1); golems are NOT in pi sessions
```

Dates are local midnight (`AUDIT_TZ`, default America/Edmonton). `--json` keeps
the raw per-session rows for follow-up questions. The script reprices 1h cache
writes at 2x input on Anthropic models (pi bills them at the 5m rate through the
gateway, pi#9210); "true $" is the number to quote.

## Read the report in this order

1. **Spend split.** cacheWrite and cacheRead dominate long Claude sessions;
   output is usually <20%. If cacheWrite > cacheRead, misses are the story.
   The `1h TTL` line must stay net positive; if the premium exceeds the
   rewrites avoided, `PI_CACHE_RETENTION=long` is costing money.
2. **Context size.** Share of spend above 200K vs share of turns. Week 36
   baseline: 40% of turns, 65% of spend. Pi's auto-compaction never fires on
   1M-window models; the `context-cost` extension nudges, habits (/new per
   work item, /compact before stepping away) do the rest.
3. **Cache misses by cause.**
   - `first`: session starts, cheap, ignore.
   - `idle`: resume after >= 1h. Each is a full rewrite at ~$4-9 for a
     200-500K context. Count x avg ctx is the "start a new session instead"
     bill.
   - `unexplained`: same model, gap < 1h, not even the system prompt hit.
     Baseline ~1% of eligible turns on every model. The cross-session
     clustering number is the discriminator: high clustering = shared
     momentary cause (gateway backend switch, transport retry after a
     dropped connection). Check `Hard stops` for "Connection error" /
     "Request timed out" in the same hours, and whether routing pins are
     active (`gateway-routing.ts` extension + `only` in models.json since
     2026-09-05). If the rate fell after the pins, backend switching was it.
   - `modelswitch` / `compaction`: expected, small.
4. **Models.** Per-model unexplained-miss rate should be roughly equal; an
   outlier model points at its provider path.
5. **Tools.** `bash: nonzero exit` is normal work. Flag `schema validation`
   errors, and read the edit-health lines: a model above ~2% malformed edits
   is a provider/stream problem, not a prompt problem (sonnet-5 ran 12% in
   week 36; pi#9212).
6. **Hard stops.** Aborts are the user; `error` rows are transport. Cluster in
   time with the unexplained misses.
7. **Top sessions.** Anything above ~$100 deserves one sentence: was the
   context size earned (real multi-day work) or drift (a triage session that
   became a workspace)? Summoners doing 400+ tool calls at 300K context are a
   delegation opportunity: familiars run at sonnet prices in fresh contexts.
8. **Openers.** Repeated first-4-word patterns are prompt-template candidates
   (`/issue`, `/lede`, `/pr` exist; check `~/.pi/agent/prompts/` before
   proposing).
9. **Constructs.** `summons.log` gives dispatch counts by kind/vessel;
   `anvil status --all --since` gives verdicts, attempts, and USD. Compute
   first-attempt pass rate and how often escalation rescued a run. Crashes
   with no result JSON (`~/scratch/logs/golem-*.json` empty) are
   infrastructure, not model, failures; read the `.log` next to them.

## Write-up shape

Lead with the one number that changed since the last audit, then footguns
(things that cost money or runs and have a fix), opportunities (a habit, a
template, an extension), gaps (things nobody can see), minor. Each item: the
number, the cause, the fix or the experiment that would settle it. Save the
report to `~/scratch/sessions-<window>-assessment-notes.md`; baselines to
compare against live in `references/baselines.md` next to this file. Update
that file when a week moves a number materially.

## Known artifacts this audit has produced

pi#9210 (1h cache accounting), pi#9211 (gateway routing inert), pi#9212
(sonnet-5 truncated edit inputs), npm/cli#9715 comment (cooldown vs fresh
worktrees), vieko/anvil#40, dotfiles extensions `gateway-routing.ts` and
`context-cost.ts`, prompt templates `/issue` and `/lede`, `summon-golem -e`,
anvil per-attempt USD cost. Check their state before re-recommending.
