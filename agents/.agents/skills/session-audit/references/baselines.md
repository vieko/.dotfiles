# Baselines

Numbers to compare against. Update when a week moves one materially; keep the
old row so drift is visible.

## Week 36 (2026-08-31 to 2026-09-05, Mon-Sat), PHYREXIA

- 108 sessions with turns, 8,533 assistant turns, 768 user turns, 8,539 tool
  calls (247 errors). pi-reported $1,485; true $1,807.
- Split (pi-reported): cacheRead $690, cacheWrite $547, output $248.
- 1h TTL: premium $332 vs $695 of rewrites avoided; net +$362. Keep `long`.
- Context: 40% of turns >= 200K carried 65% of spend; max ctx 620K;
  auto-compaction fired 4x all week.
- Misses: idle 56 ($247, avg 234K); unexplained 96 ($392, avg 233K), ~1% of
  eligible turns on every model (fable 1.0%, sonnet 0.9%, astra 2.3%, sol
  2.5%), 17-31 of them clustered within 3 min across sessions. Routing pins
  were inert this whole week (pi#9211); `gateway-routing.ts` + `only` went
  live 2026-09-05 ~12:30. Next week's unexplained rate is the experiment.
- Edit health: sonnet-5 19/154 malformed (12.3%); fable 0/196; astra 0/29.
- Hard stops: 18 (10 user aborts, 6 transport errors, 2 probe 400s).
- Constructs: 46 golems (42 luna, 2 opus, 2 fable), 17 familiars (11 sonnet).
  Golems 37 passed / 8 failed / 2 crashed (npm/cli#9715). Escalation to
  opus/fable rescued 10 on attempt 2.
- Openers: "load details for GTMENG-…" x6, "check/investigate/assess this:
  <clipboard>" x12 -> `/issue` template added.
