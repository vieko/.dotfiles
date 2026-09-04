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

## Host hazards

- **SentinelOne SIGKILLs code-like argv.** This host runs SentinelOne
  (sentineld + friends); it kills processes whose command line looks like
  obfuscated shell -- instant "Killed: 9" (exit 137), nothing in the
  kernel or syspolicyd logs, and no error a retry can get past (content
  rule, not a race). Observed 2026-09-02: golem completion pings carrying
  gate commands (grep -E, sed, xargs, `$(...)`) in a `--body` argument
  died on every attempt across three runs; the identical 2 KB body
  delivered over stdin; a `python3 -` call with 2.5 KB of markdown argv
  died the same way (so not node- or anvil-specific). The rule: **never
  put code-like or long generated text on a command line -- pass it via
  stdin or a file.** Applies to `pi-post send --body`, `node -e`,
  `python3 - "$x"`, `gh pr edit --body`, and anything similar.
  summon-golem.sh pipes its ping body over stdin since ec819d4.

## Vessels

Which model a construct is bound into. Available vessels are per-host
(for Pi: `~/.pi/agent/hosts/enabledModels.<host>.json`); this is the
PHYREXIA binding policy, grounded in session history (2026-06/07) and this
host's work profile (production TS monorepo, gated prod migrations,
governance-heavy coordination). Defaults, not law -- override per summoning
when the work demands it.

- **Summoner** -- `claude-fable-5.1:high` (the Pi default; the seat opus held
  before it). The judgment seat gets the daily-driver frontier vessel.
  Escalate to `claude-opus-5:medium` for the gnarliest architecture or
  review passes -- that is its defined job.
- **Familiar** -- `claude-sonnet-5:medium` by default; the sonnet tier is
  the organic worker tier (~1/4 of all sessions). Escalate to the
  Summoner's vessel only when the summoning names WHY judgment dominates
  (governance paths, prod-impact calls, ambiguous spec the familiar must
  resolve alone) -- "owns a whole phase" is not by itself a reason. The
  test: a brief tight enough to delegate with a verify gate is sonnet
  work by definition. Observed 2026-08-30 audit: ~11 of 14 script-summoned
  familiars over three weeks ran `-m fable` -- the escalation clause had
  inverted the default in practice; that is the drift this wording exists
  to stop.
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
- **The Summoner's own tool commands are the leak, not just constructs.**
  Three times on 2026-09-03 a summoner command landed in the shared
  `~/dev/gtm` checkout while every construct was correctly isolated:
  `git stash` / `stash pop` around an inspection popped another session's
  entry (`refs/stash` is one ref for ALL worktrees of a repo, so a no-op
  stash followed by a pop takes whatever is on top); the same pair a second
  time in an anvil worktree; and a `cd <worktree> &&`-less multi-line
  command whose `cd` failed, so `prettier --write` ran on `main`'s file.
  Rules: never `git stash` in a repo with more than one worktree; inspect
  other refs with `git show <ref>:<path>` or a throwaway
  `git worktree add /tmp/x <ref>` (removed after), never `git checkout` in
  the shared checkout; every multi-step bash tool call starts with
  `cd <worktree> && ...` as one chain, so a failed `cd` stops the chain
  instead of running the rest in the previous cwd.

- **A gate must be satisfiable inside `--scope`, against the fork SHA.**
  golem-14121 (2026-09-03) had `--scope apps/dse-platform/**` and a
  `comment-lint --all` gate; `main` had grown two stale paths in
  `apps/athena` between the summoner's zero-findings check and the fork, so
  the only way to green was to edit out of scope, and anvil voided a
  correct run. Same day, a `git diff --name-only <fork> | xargs prettier
  --check` gate fed moved `.png` files to prettier, which errors on files
  with no parser; the golem "fixed" `.prettierignore` (config drift to
  satisfy a gate). Before dispatch: run every gate on the fork SHA itself
  and confirm green; scope repo-wide lints to the changed files or the
  scope; mirror CI's filters (quality.yml checks `*.ts *.tsx *.md` only).
  A gate the golem satisfied by touching config or out-of-scope files is a
  summoner bug, and the diff needs that part reverted before review.

- **A gate must pass on a clean run, not just fail on a dirty one.**
  golem-3307 (2026-09-03) had a gate written as
  `tsc --noEmit | grep -v validator | { ! grep -q error; }` under
  `set -o pipefail`. On a clean tree `grep -v` emits nothing and exits 1,
  pipefail propagates it, and the gate reads "failed" precisely when the
  code is correct; the golem burned its retries chasing a phantom. Grep
  pipelines are exit-code traps: `grep -v` fails on empty output, `grep -q`
  fails on no match, `! cmd` inside a group does not un-fail the pipe.
  Write gates as explicit counts (`n=$(tsc ... | grep -vc validator);
  [ "$n" -eq 0 ]`) or a script that exits on a boolean it computed, run
  the gate on the fork SHA before dispatch, and check it is green there,
  not only that it goes red when you plant an error.

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

- **Gate commands run in the golem's login-shell env, not the summoner's
  bash tool.** `CDPATH` is set there, so `cd` echoes the resolved path;
  a `$(cd "$d" && cmd | grep -c x)` capture comes back as two lines and
  `[ "$n" -le 2 ]` dies with "integer expression expected". Observed
  2026-09-02 (golem-3251c): the gate was validated green in the summoner's
  tool, burned all three attempts in the golem, and the golem correctly
  diagnosed it and refused to touch the gate. Never `cd` inside a captured
  substitution in a gate; pass paths to the tool (`tsc -p "$d/tsconfig.json"`)
  or `unset CDPATH` first, as `scripts/verify-athena.sh` does. Validate
  gates in a login shell (`tmux new-window`), not only in the bash tool.
  Corollary: a gate the golem cannot satisfy is a summoner bug; read the
  golem's diagnosis before re-dispatching.

- **A golem gate for a shared package builds its consumers.** golem-3256
  fixed `import('./utils')` to `import('./utils.js')` in
  `packages/bounty-scoring` (correct for tsc under NodeNext, correct under
  vitest) and the gate passed typecheck + lint + tests. gtm-workflows'
  Turbopack build then failed: raw `.ts` consumer, no `.js` remap. Caught
  by the Vercel review bot, not the gate. When a spec touches source (not
  tests) in `packages/*`, add `pnpm --filter <consumer> build` for at least
  one bundler consumer to `--verify`, or the golem is proving the wrong
  thing.

- **Scry by the variable the decision turns on, not the one at hand.**
  GTMENG-3262 measured lint memory on the four apps with the most
  warnings, found lead-web at 2.9 GB, and called it the outlier. Nine apps
  set `parserOptions.project`; athena was 4.4 GB. Dropping the CI heap
  override on that reading OOM-killed the next wide PR. The cheap fix was
  `grep -l 'project:' **/eslint.config.mjs` before measuring anything. A
  sample chosen for convenience answers a different question than the one
  being asked.
