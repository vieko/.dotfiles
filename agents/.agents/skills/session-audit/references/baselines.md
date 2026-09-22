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

## Weeks 37-38 (2026-09-06 to 2026-09-17, 12 days), PHYREXIA

- 90 sessions with turns, 9,413 assistant turns, 771 user turns, 9,776 tool
  calls (431 errors). pi-reported $2,088; true $2,362 (~$1,380/week).
- Split (pi-reported): cacheRead $937, cacheWrite $948, output $201.
- gpt-6-astra: 24% of turns, 50% of spend ($1,183). cacheRead $1/M vs
  fable-5.1 $0.25/M; 175 of 197 turns >= 400K. Astra cache is OpenAI's:
  miss rate 3.3% at <5m gaps, 12% at 5-15m, 29% at 15-60m. Do not model it
  with a 1h TTL (audit.mjs fixed 2026-09-18; context-cost.ts still does).
- 1h TTL (anthropic/* only): premium $274 vs $394 avoided; net +$120/12d
  (fable-5.1 +$100). Thinner than week 36; keep `long`, re-check.
- Context: 26% of turns >= 200K carried 58% of spend (week 36: 40% / 65%);
  max ctx 523K; compaction 30 events in 17 sessions (week 36: 4).
- Misses: idle 79 ($292, avg 183K); unexplained 208 ($670, avg 187K); rate
  fable-5.1 1.86%, astra 3.80%, sonnet 1.25%, fable-5 2.73%; 20% clustered
  cross-session (was 37%). Scales with ctx: 1.3% <100K -> 4.6% >=400K.
  Routing pins (`only`) live all window and did not lower the rate.
- Edit health: sonnet-5 24/224 schema failures (10.7%) AFTER the strict-tools
  fix of 09-08; fable/astra 0. Strict is not landing on the gateway route.
- Hard stops: 56 (30 in the 09-10 gateway storm, 16 user aborts).
- Constructs: 62 golems (53 luna, 9 fable), 21 familiars (18 sonnet). anvil
  56 runs: 51 passed / 4 failed / 1 stale verifying; 39 first-attempt passes,
  12 fable rescues on attempt 2; $240 (fable $238.56). 2 crashes with empty
  JSON (luna moderation, fnm alpha node).
- Recurring messages: "draft a lede for" x43 (/lede), bare pi-clipboard path
  x31 (57 incl. prefixed), "proceed[ with a|b]" x44, "posted, merge it" x13.
