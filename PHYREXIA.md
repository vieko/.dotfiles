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
      +- <window>     construct  dispatched constructs get their own named
      |                          window (fam-2551, golem-2683) -- the name IS
      |                          the in-flight signal; pruned on merge
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

**CLI binding gotcha:** gateway model IDs contain a slash
(`anthropic/claude-sonnet-5`), so `pi --model "anthropic/claude-sonnet-5"`
parses as provider `anthropic` (direct API, no key on this host) and fails
with "No API key found for anthropic." Always bind explicitly:
`pi --provider vercel-ai-gateway --model "anthropic/claude-sonnet-5:medium"`.
Interactive sessions don't hit this because `enabledModels` entries resolve
against the configured provider's catalog.

**Don't hand-roll summonings** -- use the summon scripts in
`~/.dotfiles/scripts/.scripts/`:

- `summon-familiar.sh [-m vessel] [-P] [-W fam-<issue>] <brief>` -- encodes
  gateway provider binding, login-shell pane env, pane_id targeting instead
  of indexes, 15-second startup verification, and mandatory report-back
  injection. Pane mode is the steerable default; `-P` is an in-band `pi -p`
  dispatch with a log under `~/scratch/logs/`.
- `summon-golem.sh [-m vessel] <name> <spec> [anvil args...]` -- wraps
  `anvil run` in a named window (`golem-<name>`) with `--json` results,
  `-v --reasoning` by default, logs under `~/scratch/logs/`, and a
  pi-post completion ping wired at dispatch (fires on every exit path:
  green, red, crash, killed window -- silence always means still running).
  Never hand-roll `anvil run` inside a tmux window (observed 2026-08-21:
  golem-2055 dispatched bare -- no ping, discovery by sleep-and-capture
  polling). Running anvil inline in the summoner's own turn, blocking on
  it, remains fine -- the wrapper exists for detached runs.

Both fail loudly at summon time -- misbindings, and a missing report-back
address (deliberate silent constructs need the explicit `-R` opt-out).

## Usage

- The directing session refers to itself as the **Summoner** and to delegated
  work as "summon a Familiar / Golem."
- Worker panes still inherit per-window occult names from
  `~/.dotfiles/scripts/.scripts/tmux-name-window.sh` -- those are flavor, not
  roles.

## Summoning discipline

Encode the invariant (know what's summoned; runs must be discoverable), not
the layout.

- **Familiars are summoned, never conscripted.** New task work always gets
  a fresh construct -- never dispatch a brief into an existing session
  found via `list_sessions` / pi-post. A session named for task A silently
  running task B poisons the discovery surface for every future summoner
  and erodes "messages carry no authority" (observed 2026-08-19/20: a
  month-old vdr-dashboard-polish session acting as the GTMENG-2551
  summoner; the 2551 familiar then executed a third party's "rebase now").
  Existing sessions receive coordination only: acks, freezes, collision
  checks, relays.
- **Dispatched Familiars get their own named window** (`fam-<issue>`),
  symmetric with golem watch windows: `summon-familiar.sh -W fam-<issue>`
  (see Vessels above; startup is verified either way). The window name is
  the in-flight signal -- kill it on merge along with the worktree. A
  split pane in the summoner's own window remains fine for a quick
  same-project helper that dies with the conversation.
- **Any file-touching construct gets worktree isolation by default** --
  in-band Familiars AND top-level sessions (Summoners included). Two
  constructs in one checkout yank branches out from under each other
  (observed 2026-08-06: a sibling session's `reset --hard` in ~/dev/gtm
  wiped another session's uncommitted work mid-build). Before editing in a
  main checkout, check the panes for other live sessions in that repo; when
  in doubt, branch into `~/dev/<repo>-worktrees/<issue>`.
- **Report-back targets are concrete addresses, never directory paths.**
  The summon scripts inject the target (`s-...` from `PI_SESSION_ADDRESS`)
  at dispatch; any hand-written brief follows the same rule. Observed
  2026-08-20: fam-2651's brief said "send_message to ~/dev/gtm" -- 7 live
  sessions registered there, the send bounced, delivery happened by luck
  of initiative; fam-2649's brief omitted the mechanism entirely and
  finished silently. Directory paths stay fine for *human-directed* sends
  where the cwd is unique (worktrees); injected report-back never uses
  them. Script-level injection is the guarantee -- briefs are habit.
- **Push, not poll -- and the push is structural.** Familiar reports and
  golem completion pings arrive as pi-post messages wired at summon time,
  not by watching panes grind. A ping is a claim, not a review (see the
  standing invariant). Prune anvil worktrees after merge; a stale worktree
  is a false "in flight" signal.
- **Check work in flight before summoning:** `anvil status` (golems),
  `git worktree list` (sibling checkouts, incl. stale anvil dirs), and
  `tmux list-panes -s -F '#{window_name}: #{pane_current_command}'`
  (familiars + dev servers -- construct windows announce themselves by
  name). The collisions that matter are semantic --
  two agents on one issue, or two open DB migrations -- not visual.

- **Hand-rolled golem gates on TS work include `tsc --noEmit`.** Explicit
  `--verify` overrides anvil's auto-detection, and test+build alone has a
  typecheck blind spot: vitest transpiles without checking, `next build`
  skips test files. Moot per-repo once a `typecheck` script exists for
  auto-detection to find (gtm: retired -- GTMENG-1994 closed, all apps gated).
