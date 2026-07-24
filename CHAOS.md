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

Inherits PHYREXIA's roles and standing invariants unmodified (Summoner /
Familiar / Golem / Legion, steerability-defined Familiars, the standing
review gate -- see `~/.dotfiles/PHYREXIA.md`). Both former CHAOS amendments
were backported into PHYREXIA.md on 2026-07-24; they were earned in the
field here (Bootleg Arcade hardening epic, 2026-07-22 -- two constructs
corrected mid-run instead of re-run from scratch).

## Vessels

PHYREXIA's binding policy applies (fable Summoner, sonnet-default
Familiars bound up per phase, luna-default Golems for cross-family
anti-collusion, sonnet Legions). CHAOS deltas:

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
