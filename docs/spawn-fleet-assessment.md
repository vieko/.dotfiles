# Spawn fleet assessment (2026-11-03)

What Spawn's agent fleet means for the PHYREXIA setup, and what the local
data says. Measurements first, proposals after; no proposal is built yet.

Sources: Jacob Sansbury, "How I Built the Most AI-Pilled Company in the
World" (x.com/jsnnsa/status/2115623382721126826), and Simon Willison's link
post of 2026-10-29. Spawn's figures are self-reported.

Scripts and raw output live in `~/scratch/data/` (ephemeral):
`menu-extract.mjs`, `menu-classify.mjs`, `rec-reversible-labels.json`,
`batch-size.py`, `spend-days.mjs`.

## Measurements

### Lettered menus and replies, 2026-09-21 .. 11-03 (W39-W45)

Earlier sessions are mostly pruned, and menus before then seldom marked a
recommendation.

- 3,021 user turns; 413 replied to a lettered menu (14%).
- Took the recommended option with nothing added: 206 (50% of menus).
  Hand-labelled against the global destructive guard plus external writes:
  - 115 local and reversible (28% of menus, ~18 a week)
  - 20 external writes (PRs, Linear state, issues, comments, CI reruns,
    messages to people)
  - 61 hard gates by regex (push, merge, send, post, migrate, ...)
  - 6 scratch deletions, 2 other local irreversible (`rm -rf`, kill)
  - 2 prod DB writes
- Took the recommendation and added new direction: 82 (20%).
- Picked another option: 16 (4%); 4.7% of letter picks that had a marked
  recommendation. Most turn on information only the user had (a person's
  sign-off, issue scope) or on preference.
- Free text: 52 asked a question back (13%), 57 redirected (14%).
- Median time to reply: about one minute.

Reading: Spawn's precedent judges would have little to decide here, because
the overrides depend on information that is not in the record. The 115
local-reversible menus are checkpoints that the "Ask or proceed" rule in
`pi/.pi/agent/AGENTS.md` already tells the agent to skip; the one-token
share has stayed at 19-22% since that rule landed. The gain is fewer
interruptions, not saved wait time.

### Golem spec size vs outcome

108 golem runs joined from `~/scratch/logs/summons.log` to anvil run
records. Luna base only (fable costs $10-27 in every bucket):

| spec words | n  | rung-0 pass | median $ | mean $ |
|------------|----|-------------|----------|--------|
| < 400      | 24 | 83%         | 0.05     | 0.37   |
| 400-800    | 38 | 87%         | 0.03     | 0.29   |
| 800-1500   | 20 | 65%         | 0.06     | 1.80   |
| 1500+      | 6  | 50%         | 1.38     | 2.75   |

Repair specs: n=9, median $10.88, median cumulative context 10.7M. Word
count is a weak proxy for scope and the large buckets are small; this
supports the existing split-repair-specs rule in `PHYREXIA.md` rather than
adding a new one.

### Spend baseline (pi sessions only; anvil spend is in its run records)

- Per day, 39 days: median $47, p90 $121, max $267.
- Per session-hour: p50 $1.47, p95 $6.95, p99 $13.45, max $21.56.
- Local logs cannot see a leaked gateway key. That needs gateway-side usage.

## Proposals (unbuilt)

1. Sent-back nudge in `habit-nudges.ts`: when a turn ends on a menu whose
   recommended option is local and reversible, tell the agent to proceed.
   Shadow mode first: log the verdict and compare with the reply.
   Shadow mode built 2026-11-11 as `pi/.pi/agent/extensions/menu-shadow.ts`;
   the criteria are in the session-audit skill, "Open experiments".
2. Spec-size warning in `summon-golem.sh` for luna specs above ~800 words.
3. Stall nudge: a session-hour above ~$13 (p99), an anvil run above 10M
   cumulative context, or a construct window with spend and no commit for
   a set time.
4. Gateway-side spend check for leak detection.

## Standing owner agents

- Local, on PHYREXIA: a named session with a charter and memory, woken by
  `remind-at.sh` and pi-post. It conflicts with "Familiars are summoned,
  never conscripted" and needs its own role in `PHYREXIA.md`.
- Vercel Sandbox: no access to local state (pi-post, `~/scratch`, the SFDC
  exit node); blocked on anvil #58 like the sandbox lane. A wish for an
  always-on agent is a reopen trigger for the Pi Durable assessment.

## Deferred

The full trunk-only fleet model runs later on chaos as a separate project,
not in gtm or on PHYREXIA.
