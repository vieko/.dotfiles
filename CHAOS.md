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
      +- panes        agents     each pane runs an agent session

Same shape as PHYREXIA. `anvil` and `pi` are installed here.

## Roles

Inherits PHYREXIA's roles (Summoner / Familiar / Golem / Legion -- see
`~/.dotfiles/PHYREXIA.md`) with two CHAOS amendments, both earned in the field
(Bootleg Arcade hardening epic, 2026-07-22):

- **Familiars are defined by STEERABILITY, not by panes.** A Familiar is any
  steerable same-runtime worker: an interactive pane session *or* an in-band
  background dispatch (Agent-tool subagent in its own worktree) that the
  Summoner can message mid-flight. Steering is the point -- two constructs
  were corrected mid-run instead of re-run from scratch. A Golem is the
  unsteerable kind: gate-bound, no conversation (Anvil or equivalent);
  mechanism is flavor, the property is identity.

- **The review gate is a standing invariant, not a Legion clause.** EVERY
  construct's diff passes one review pipeline, and judgment sits with the
  session holding the richest context (usually the Summoner). PHYREXIA's
  Legion warning generalizes: a green gate cannot distinguish "make the test
  pass" from "the test was lying" -- the review gate exists to tell them
  apart, and it catches what no gate can (planted probe strings, contracts
  that enshrine the bug, prose that satisfies a grep).

## Summoning discipline

PHYREXIA's discipline applies (check `anvil status` / `git worktree list` /
panes before summoning; push-not-poll; prune worktrees after merge; tsc in
hand-rolled gates). CHAOS additions:

- **In-band Familiars get worktree isolation by default** when they touch
  files -- two constructs in one checkout yank branches out from under each
  other.
- **Capacity:** untested ceiling; assume PHYREXIA's 3 concurrent heavy
  sessions until measured otherwise.
