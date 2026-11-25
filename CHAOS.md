# CHAOS session lexicon

Personal, machine-local naming convention for multi-agent work on this host
(personal machine; the work-machine counterpart is `PHYREXIA.md`). Not a team
convention -- never propagate into team repos. Surfaced via the pointer in
`~/.claude/CLAUDE.md`; this file is the source of truth for CHAOS.

## Topology

    CHAOS             plane      tmux session / machine
      |
      +- <window>     project    one window per project
      |
      +- <window>     construct  named per task (fam-2551, golem-2683),
      |                          pruned on merge
      |
      +- panes        agents     each pane runs an agent session

Same shape as PHYREXIA. `anvil` and `pi` are installed here.

## Roles

Inherits PHYREXIA's roles and standing invariants unmodified (Summoner /
Familiar / Golem / Legion, steerability-defined Familiars, the standing
review gate -- see `~/.dotfiles/PHYREXIA.md`). Both former CHAOS amendments
were backported into PHYREXIA.md on 2026-07-24; they were earned in the
field here (Bootleg Arcade hardening epic, 2026-07-22 -- two constructs
corrected mid-run instead of re-run from scratch).

## Vessels

PHYREXIA's binding policy applies (opus Summoner, sonnet-default
Familiars with escalation only for a named reason, luna-default Golems
for cross-family anti-collusion, sonnet Legions). CHAOS deltas:

- **Claude Code on the Max plan (2026-11-25):** Summoner and `builder`
  default to opus; `fable` is an escalation for one session (`/model
  fable`) or one spawn (Agent `model` override), with the reason named.
  `advisorModel: fable` stays: an opus builder with a Fable advisor is
  Anthropic's cheap-executor/strong-advisor pairing. Builders consult it
  at most once, at planning, only when the brief leaves the design open;
  never for pattern work (pilot/deck/list) or before done (the review
  gate covers that). Why: week of 2026-11-18, about 81% of the Fable cap
  went to Fable builders and their Fable-on-Fable advisor calls (82 runs,
  mostly battlemox pilot/deck/list work), against 18% for the directing
  sessions. Evidence: `~/scratch/claude-token-usage-assessment.md`.
- **Builder trials (2026-11-25, review 2026-12-09):** `effort: medium`
  (thinking was 31% of builder output at high) and `autoCompactWindow:
  250000` (was 400K; 59% of builder cache reads came from calls above
  200K). Keep both if finish and merge rates hold; revert either one if
  runs fail or redo work more often.
- **Directing-session handoff:** hand off at about 250K of context or 150
  turns. One battlemox Summoner ran 989 turns over 3.5 days; every late
  turn re-read 300-600K.

- **Wider pool (unrestricted gateway key):** `kimi-k3:high` and
  `grok-4.5:high` are also enabled here -- they join the consult pool and
  are viable alternate Golem / Legion vessels when even more family
  diversity is wanted under the review gate.
- **Stakes discount:** personal work (sites, game spikes, agent tooling)
  carries no prod migrations or governance gates -- binding down
  (`sonnet` Summoner for small sessions, `haiku` Legion members) is fine
  here in ways it isn't on PHYREXIA.

## Summoning discipline

PHYREXIA's discipline applies in full (check `anvil status` /
`git worktree list` / panes before summoning; in-band worktree isolation;
push-not-poll; prune worktrees after merge; tsc in hand-rolled gates).
CHAOS addition:

- **Capacity:** untested ceiling; assume PHYREXIA's 3 concurrent heavy
  sessions until measured otherwise.
