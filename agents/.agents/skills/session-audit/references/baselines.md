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

## Week 39 (2026-09-18 to 2026-09-26, 7 working days), PHYREXIA

- 162 sessions with turns (52 of them one-shot sol image-batch familiars, 10
  probes), 8,900 assistant turns, 770 user turns, 8,779 tool calls (323
  errors). pi-reported $763; true $892 (~$640/week, from ~$1,380).
- Split (pi-reported): cacheRead $345, cacheWrite $237, output $177.
- gpt-6-astra: 165 turns, $30 (from $1,183). 8 of 9 sessions were one-sitting
  review familiars. The "astra is a bounded vessel" rule held.
- 1h TTL (anthropic/* only): premium $128 vs $563 avoided; net +$435.
- Context: 20% of turns >= 200K carried 31% of spend (was 26% / 58%); max
  ctx 565K; all 175 turns >= 400K in one $104 session (09-23 screenshots).
- Misses: idle 35 ($70, avg 132K); unexplained 60 ($72, avg 124K), 14/60
  clustered. fable-5.1 0.39% (22/5,587), 18 of 22 in two morning clusters
  (09-18, 09-22); 09-23 onward 4 in ~3,000 turns. sonnet 1.42%, sol 1.57%,
  astra 1.28%. Cause of the drop unproven (compat mirroring 09-21, pi 0.87.1
  09-22, or cluster luck); next window decides.
- Edit health: sonnet-5 28/233 (12.0%, 9 familiars, all before 09-22 15:00);
  sol 0/272; fable-5.1 0/160; fable-5 0/43; astra 0/8. Sonnet question closed.
- Hard stops: 15 (8 aborts, 2 `pi update` module-not-found, 2 Connection
  error, 1 timeout, 1 413 on a 50-image sol familiar).
- Constructs: 31 golem dispatches (28 luna, 3 fable) -> 22 anvil runs, 21
  passed / 1 failed (spec assumption), 19 first-attempt passes (86%), 1 luna
  same-model retry, 1 fable rescue; $7.41 total (luna $0.66). 93 familiars
  (72 sol incl. 52 print-mode image batches, 9 sonnet, 8 astra, 4 fable).
  5 infra crashes with empty JSON (2 runner PATH, 1 `.git/config` lock race
  between parallel golems, 1 bad --contract path, 1 transient npm ETARGET).
- `cacheWarming: "idle"` produced 0 `cache_warm` usage entries: the 54-min
  refresh (90% of 1h TTL) is past pi's fixed 30-min idle cap. Inert.
- Recurring messages: "proceed with (a)" x21 + "proceed with a" x10 +
  "proceed" x8; "posted" x11 + "posted, merge it" x9; "draft a lede for" x14;
  bare pi-clipboard path x17; "anything else for this" x8 (new).

## Week 40 (2026-09-27 to 2026-10-04, 7 working days), PHYREXIA

- 55 sessions with turns, 5,852 assistant turns, 632 user turns, 5,254 tool
  calls (230 errors). pi-reported $458; true $486 (~$420-490/week, from
  ~$640). First window with fork dedupe in `audit.mjs`: two `/fork`s had
  duplicated 443 turns / $36 / $4.44 counsel; earlier baselines are
  inflated by whatever forking they contained (direction holds).
- Split (pi-reported): cacheRead $205, cacheWrite $149, output $104.
- Models: fable-5.1 2,834 turns $318 (312 user turns, $1.02/ut; $1.22
  excluding the $112 drift session); opus-5.5 2,199 turns $145 (305 user
  turns, $0.48/ut); sol 810 turns $22 (7 familiars). Aborts: fable 9, opus 8.
- 1h TTL (anthropic/* only): premium $65 vs $275 avoided; net +$210.
- Context: 26% of turns >= 200K carried 35% of spend; max ctx 491K. Two
  drift sessions (09-22 index transcription $112, 4 active days, 5
  compactions; 09-28 3758 handoff $61, 457K) = 36% of spend.
- Misses: idle 24 ($45, avg 128K); unexplained 12 ($5): fable 0.07%
  (2/2,772), opus 0.05%, sol 1.13% (9/798, OpenAI best-effort at 0-1m gaps).
  Size-tax finding retired.
- Edit health: fable 1/77, opus 0/52, sol 0/240 malformed.
- Hard stops: 40. 8 = gateway 400 `messages.N.content: Invalid input` on
  `tool_addition` blocks (10-03, fixed by `supportsMidConvoToolChanges:
  false`, dotfiles ede7e5b); 14 Request timed out in two clusters (09-30
  18:40-21:10, 10-02 14:1x); 17 aborts; 1 503.
- Counsel: 7 consults (5 fable:high $7.78, 2 haiku probes), avg $1.11,
  1.6% of session spend, 5 revise / 2 stop, cache-read share 0%.
- Constructs: 1 golem (luna, passed attempt 1, $0.03), 7 sol familiars
  (3 of them `*-spec.md` executions, golem-shaped).
- Recurring messages: "proceed with (a)" x28, "(a)" x27, "a)" x14 (81 of 632
  user turns are one-token decisions); "draft a lede for" x12 (all `/lede`
  expansions); "anything else for this session?" x8; "pi was just updated"
  x3 as an opener.
