# PHYREXIA session lexicon

Personal, machine-local naming convention for multi-agent work on this host.
**Not a team convention** -- never propagate into project/team repos. Both Pi
and Claude Code surface it via a pointer in their global config
(`~/.pi/agent/AGENTS.md`, `~/.claude/CLAUDE.md`); this file is the source of
truth.

## Topology

    PHYREXIA          plane      tmux session / machine (set-default-session-name.sh)
      |
      +- <window>     project    one window per project; window name is random
      |                          occult flavor (tmux-name-window.sh) -- not a role
      |
      +- panes        agents     each pane runs an agent session

## Roles

- **Summoner** -- the directing session. Runtime-agnostic: a Pi *or* Claude
  Code session in the driving seat. It scries (explores), scopes, inscribes
  Linear issues, sequences work, and coordinates parallel sessions. It
  delegates implementation rather than doing it.

- **Familiar** -- a worker session of the **same runtime as the Summoner**
  (Pi Summoner -> Pi Familiars; Claude Code Summoner -> Claude Code Familiars).
  Same-kind, to avoid mixing harnesses.

- **Golem** -- an **Anvil** run: an isolated, gate-bound, autonomous construct
  (its own git worktree, no conversation, grinds until its deterministic gate
  passes). Usually its own pane, but the Summoner may also invoke Anvil
  directly without a pane.

## Usage

- The directing session refers to itself as the **Summoner** and to delegated
  work as "summon a Familiar / Golem."
- Worker panes still inherit per-window occult names from
  `~/.dotfiles/scripts/.scripts/tmux-name-window.sh` -- those are flavor, not
  roles.
