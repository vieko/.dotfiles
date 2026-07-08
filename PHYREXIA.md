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

- **Legion** -- a batch of Golems run in parallel against one spec template.
  Requirements: **disjoint scopes** (no shared files between members -- merge
  conflicts void the pattern), **batch-sized to machine capacity** (3
  concurrent monorepo installs/sessions is this host's comfortable ceiling),
  **one review pipeline** (each member's diff is individually reviewed before
  ship -- a Legion multiplies the mechanics, never the judgment; a green gate
  cannot distinguish "make the test pass" from "the test was lying").

## Usage

- The directing session refers to itself as the **Summoner** and to delegated
  work as "summon a Familiar / Golem."
- Worker panes still inherit per-window occult names from
  `~/.dotfiles/scripts/.scripts/tmux-name-window.sh` -- those are flavor, not
  roles.

## Summoning discipline

Encode the invariant (know what's summoned; runs must be discoverable), not
the layout.

- **Familiars run as panes in their project's window.** They are interactive;
  the topology already says where they live. Never a separate window --
  windows are projects, panes are agents.
- **Golems run headless.** `anvil status` is their presence; a pane is
  optional flavor for a human who wants to watch, never a requirement.
- **Check work in flight before summoning:** `anvil status` (golems),
  `git worktree list` (sibling checkouts, incl. stale anvil dirs), and
  `tmux list-panes -s -F '#{window_name}: #{pane_current_command}'`
  (familiars + dev servers). The collisions that matter are semantic --
  two agents on one issue, or two open DB migrations -- not visual.
- **Push, not poll:** prefer a completion notification (Slack,
  `tmux display-message`) over watching a golem grind. Prune anvil
  worktrees after merge; a stale worktree is a false "in flight" signal.
- **Hand-rolled golem gates on TS work include `tsc --noEmit`.** Explicit
  `--verify` overrides anvil's auto-detection, and test+build alone has a
  typecheck blind spot: vitest transpiles without checking, `next build`
  skips test files. Moot per-repo once a `typecheck` script exists for
  auto-detection to find (gtm: GTMENG-1994).
