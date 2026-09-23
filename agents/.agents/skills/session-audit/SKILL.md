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
   rewrites avoided, `PI_CACHE_RETENTION=long` is costing money. The TTL
   line covers `anthropic/*` only. Read the OpenAI-family share separately
   (`gpt-6-astra`, `gpt-6-sol`, `gpt-6-luna`): their cache is best-effort
   (12% misses at 5-15m idle, 29% at 15-60m, measured 2026-09-18) and astra
   reads cost 4x fable's. Weeks 37-38 astra took 50% of spend on 24% of
   turns; PHYREXIA.md now binds astra only for one-sitting work. An astra
   Summoner living past a few hours is the first footgun to name.
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
     Baseline 1-2% of eligible turns on every model. The cross-session
     clustering number separates shared momentary causes (gateway storm,
     transport retry after a dropped connection) from the size tax. Check
     `Hard stops` for "Connection error" / "Request timed out" in the same
     hours. Routing pins (`gateway-routing.ts` + `only` in models.json,
     live since 2026-09-05) did NOT lower the rate in weeks 37-38 (1.86%
     fable, 20% clustered), so backend switching is ruled out as the main
     cause; the rate scales with context size (1.3% under 100K, 4.6% at
     400K+). Report it as a size tax unless clustering jumps back above
     ~35%.
   - `modelswitch` / `compaction`: expected, small.
4. **Models.** Per-model unexplained-miss rate should be roughly equal; an
   outlier model points at its provider path.
5. **Tools.** `bash: nonzero exit` is normal work. Flag `schema validation`
   errors, and read the edit-health lines: a model above ~2% malformed edits
   is a provider/stream problem, not a prompt problem. sonnet-5 via the
   gateway ran 12% (week 36) and 10.7% (weeks 37-38) and neither strict
   tool sampling (pi 0.86 default + `supportsStrictTools` override, 09-08)
   nor the fine-grained-streaming A/B (09-22) moved it (pi#9212). Resolution
   2026-09-22: sonnet-5 dropped from the picker, familiar default moved to
   `gpt-6-sol` (0 malformed edits across 600+ GPT-family edit calls). What
   to check now: sonnet turns should be near zero (only `-m sonnet` A/B
   dispatches); any GPT-family or opus-5.5 malformed edits above ~1% is a
   new finding.
6. **Hard stops.** Aborts are the user; `error` rows are transport. Cluster in
   time with the unexplained misses.
7. **Top sessions.** Anything above ~$100 deserves one sentence: was the
   context size earned (real multi-day work) or drift (a triage session that
   became a workspace)? Summoners doing 400+ tool calls at 300K context are a
   delegation opportunity: familiars run at worker-tier (sol) prices in
   fresh contexts.
8. **Openers.** Repeated first-4-word patterns are prompt-template candidates
   (`/issue`, `/lede`, `/pr` exist; check `~/.pi/agent/prompts/` before
   proposing).
9. **Constructs.** `summons.log` gives dispatch counts by kind/vessel;
   `anvil status --all --since` gives verdicts, attempts, and USD. Compute
   first-attempt pass rate and how often escalation rescued a run. Crashes
   with no result JSON (`~/scratch/logs/golem-*.json` empty) are
   infrastructure, not model, failures; read the `.log` next to them.
   Vessel names changed 2026-09-22 (`luna` = gpt-6-luna, `sol` = gpt-6-sol,
   `opus` = claude-opus-5.5, strong rung is opus not fable, `glm`/`terra`
   dropped); older rows in `summons.log` and `anvil status` carry the old
   ids, so group by alias, not by model id, across the boundary.

## Open experiments (settle before proposing new ones)

- **Sol repair-spec pilot**: the next ~10 `*-repair-spec` golems bound
  `-m sol` vs the 11 fable repair runs in weeks 37-38 ($5-15 each). Sol
  wins on pass rate at ~1/25 of fable's token price; loses if the review
  loop goes around again.
- **opus-5.5 vs fable-5.1 as Summoner**: 40% of fable's price on every
  axis; quality parity unproven. Compare $/user-turn and abort rate.
- **sonnet-5 edit loss**: `-m sonnet` dispatches keep feeding the A/B;
  report the malformed-edit rate if any ran.
- **1h TTL net**: +$362 (wk 36) then +$120/12d (wks 37-38). If it goes
  negative, `PI_CACHE_RETENTION=long` comes off.

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
worktrees), vieko/anvil#40, vieko/anvil#44 (alias refresh, strong tier
opus-5.5), dotfiles extensions `gateway-routing.ts` and `context-cost.ts`
(TTL keyed on model family since 09-22), prompt templates `/issue` and
`/lede`, `summon-golem -e`, anvil per-attempt USD cost, PHYREXIA.md rules
"astra is a bounded vessel" and "split repair specs", pi AGENTS.md
"posted closes the loop", matter-of-fact lettered options (pi-prose 0.3.1),
model picker trimmed to 6 per host (09-22). Check their state before
re-recommending.
