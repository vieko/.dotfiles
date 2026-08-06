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

- **Familiar** -- a steerable worker of the **same runtime as the Summoner**
  (Pi Summoner -> Pi Familiars; Claude Code Summoner -> Claude Code Familiars).
  Defined by STEERABILITY, not by panes: an interactive pane session *or* an
  in-band background dispatch (Agent-tool subagent in its own worktree) that
  the Summoner can message mid-flight. Steering is the point -- correcting a
  construct mid-run beats re-running from scratch. Same-kind, to avoid mixing
  harnesses.

- **Golem** -- the unsteerable kind: gate-bound, no conversation. Canonically
  an **Anvil** run: an isolated, autonomous construct (its own git worktree,
  grinds until its deterministic gate passes). Mechanism is flavor, the
  property is identity. Usually its own pane, but the Summoner may also
  invoke Anvil directly without a pane.

- **Legion** -- a batch of Golems run in parallel against one spec template.
  Requirements: **disjoint scopes** (no shared files between members -- merge
  conflicts void the pattern), **batch-sized to machine capacity** (3
  concurrent monorepo installs/sessions is this host's comfortable ceiling),
  **one review pipeline** (each member's diff is individually reviewed before
  ship -- a Legion multiplies the mechanics, never the judgment; a green gate
  cannot distinguish "make the test pass" from "the test was lying").

## Standing invariants

- **The review gate applies to EVERY construct, not just Legions.** Each
  construct's diff passes one review pipeline, and judgment sits with the
  session holding the richest context (usually the Summoner). A green gate
  cannot distinguish "make the test pass" from "the test was lying"; the
  review catches what no gate can (planted probe strings, contracts that
  enshrine the bug, prose that satisfies a grep).

## Vessels

Which model a construct is bound into. Available vessels are per-host
(for Pi: `~/.pi/agent/hosts/enabledModels.<host>.json`); this is the
PHYREXIA binding policy, grounded in session history (2026-06/07) and this
host's work profile (production TS monorepo, gated prod migrations,
governance-heavy coordination). Defaults, not law -- override per summoning
when the work demands it.

- **Summoner** -- `claude-fable-5:high` (the Pi default; the seat opus held
  before it). The judgment seat gets the daily-driver frontier vessel.
  Escalate to `claude-opus-5:medium` for the gnarliest architecture or
  review passes -- that is its defined job.
- **Familiar** -- `claude-sonnet-5:medium` by default; the sonnet tier is
  the organic worker tier (~1/4 of all sessions). Bind UP to the Summoner's
  vessel when a Familiar owns a whole phase -- scoped PRs still hit judgment
  traps (lockfile drift, governance paths, prod-impact calls).
- **Golem** -- anvil `--model luna` (gpt-5.6-luna) by default: a
  cross-family golem under an Anthropic reviewer diversifies failure modes
  -- same-family worker+reviewer share blind spots, and the review gate
  exists to catch "the test was lying." Bind `--model opus` for deep
  refactors where raw capability dominates. Note: anvil's aliases are
  `haiku/sonnet/opus/luna` only -- there is no `fable` alias.
- **Legion** -- `sonnet` members (`haiku` only for purely mechanical
  batches -- historically unused). At a 3-member ceiling, member cost is
  noise next to merge-conflict and review cost; the gate + review carry
  the judgment, not the member.

Cross-family consults (`glm-5.2`, `gpt-5.6-sol`) are conversations, not
constructs -- a second read needs no binding.

## Usage

- The directing session refers to itself as the **Summoner** and to delegated
  work as "summon a Familiar / Golem."
- Worker panes still inherit per-window occult names from
  `~/.dotfiles/scripts/.scripts/tmux-name-window.sh` -- those are flavor, not
  roles.

## Summoning discipline

Encode the invariant (know what's summoned; runs must be discoverable), not
the layout.

- **Interactive Familiars run as panes in their project's window.** The
  topology already says where they live. Never a separate window --
  windows are projects, panes are agents.
- **Any file-touching construct gets worktree isolation by default** --
  in-band Familiars AND top-level sessions (Summoners included). Two
  constructs in one checkout yank branches out from under each other
  (observed 2026-08-06: a sibling session's `reset --hard` in ~/dev/gtm
  wiped another session's uncommitted work mid-build). Before editing in a
  main checkout, check the panes for other live sessions in that repo; when
  in doubt, branch into `~/dev/<repo>-worktrees/<issue>`.
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
  auto-detection to find (gtm: retired -- GTMENG-1994 closed, all apps gated).
