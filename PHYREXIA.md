# PHYREXIA session lexicon

Personal, machine-local naming for multi-agent work on this host. **Not a
team convention**: never put it in project or team repos. Pi and Claude
Code point here from their global config. This file has the rules only;
the incidents, measurements and trial criteria behind them are in
`docs/phyrexia-history.md` (frozen 2026-11-26). Read that file only when
you need the reason for a rule.

## Topology

    PHYREXIA          plane      tmux or Rex session
      +- <window>     project    one per project; random occult name, not a role
      +- <window>     construct  fam-<issue> / golem-<name>; the name is the
                                 in-flight signal; close it on merge
      +- panes        agents     one agent session per pane

Rex is the daily terminal (`docs/rex-assessment.md`). The summon scripts
and `remind-at.sh` pick tmux or Rex through `construct-term.sh`; tmux wins
when both are present. Rex cannot move a tab between sessions, so choose
the stream at summon time: `-S <stream>` on `summon-familiar.sh -W` and
`summon-golem.sh`.

## Roles

- **Summoner**: the directing session (Pi or Claude Code). It explores,
  scopes, writes Linear issues, sequences work and coordinates. It
  delegates implementation.
- **Familiar**: a steerable worker of the Summoner's runtime, in a pane or
  an in-band dispatch, that the Summoner can message mid-run.
- **Golem**: an unsteerable, gate-bound run, normally Anvil: its own
  worktree, done only when its deterministic gate passes.
- **Legion**: Golems in parallel from one spec template. Scopes must be
  disjoint. Capacity on this host (M4 Pro, 48 GB): 6 concurrent golems on
  scoped gates, 2 on repo-wide gates (3 with Chrome closed). Use
  `turbo run ... --concurrency=4` when a wide gate is unavoidable. Each
  member's diff gets its own review.
- **Sandbox lane**: `summon-golem.sh --sandbox` runs a golem on a Vercel
  Sandbox (project `vieko-golem-sandbox`, team
  `vercel-internal-playground`), with no secret in the VM. It is the way
  past the 6-golem ceiling, and the default lane from 2026-11-27 (the
  user's direction: sandboxes almost always). Spend needs no approval
  per dispatch or snapshot build: the budget is $10K a month for models
  and compute together, and a 4 vCPU / 8 GB sandbox costs about $0.70
  an hour at full CPU. Controller and setup:
  `scripts/sandbox/`, `docs/agent-maintenance.md` ("Sandbox lane"); ids in
  `~/private/lanes/sandbox-golem.env`.
- **Remote familiar** (first slice, 2026-11-27): `remote-familiar start
  -r owner/repo <brief>` runs a familiar as a durable-harness Pi session
  with its own Vercel Sandbox VM and Drive. One driver (launchd agent,
  `remote-familiar driver install`) runs the agent loop and model calls on
  this host; the VM gets no credentials. The familiar publishes through
  `request_publish`: checks, a review model that can only hold or deny,
  then the approval inbox; after approval the driver commits on
  `vercel-sandbox/<name>` with GitHub-signed commits and opens the PR.
  It reports over pi-post and shows in the Sigil overview. Steer it with
  `send_message` to its address (the summoner's message gets the summoner
  stamp), `remote-familiar send <name>`, or the message box on its card
  in the Sigil overview (the user stamp: it speaks for the user on scope,
  never for a publish): mid-turn it lands as a steer,
  after its report it starts a new turn on the same VM, and a second
  `request_publish` adds a commit to its open PR. One model per driver.
  Code: `scripts/familiar-remote/`.
- **Scout**: a read-only child from the `scout` tool (haiku, read-only
  tools, up to 8 tasks). It writes nothing, so it is not a construct. Its
  report is an unreviewed claim: open the cited lines before an edit or a
  spec depends on it. Point it at a detached worktree at `origin/main`
  when the shared checkout is behind.

## Standing invariants

- **Every construct's diff passes one review**, by the session with the
  richest context (usually the Summoner). A green gate cannot tell "the
  test passes" from "the test was lying".
- **durable-harness is the substrate for remote familiars only.** Its
  reopen trigger (constructs leave this host) was met on 2026-11-27.
  Local familiars stay on the pi CLI and golems on anvil; Pi Durable and
  harness-on-world are still not construct substrates here.

## Host hazards

- **SentinelOne kills a process with a long or code-like argument**
  (about 1000+ bytes in one argv element, prose included; exit 137, no
  log). Pass long or generated text through stdin or a file: `pi-post
  send`, `gh pr edit --body`, `linear ... --description`, `node -e`,
  `python3 - "$x"`. Long Linear bodies: the curl recipe in the
  `linear-cli` skill.
- **Salesforce needs the `egress-pdx` Tailscale exit node** (static IP
  `5.78.100.55`). The symptom when it is off is `400 invalid_grant: ip
  restricted`. Check with `curl -4 ifconfig.me` before you dispatch work
  that reads SFDC. Turning it on is the user's action, not an agent's.
- **Keyboard chords are layered.** Read `docs/keybindings.md` and run
  `~/.scripts/keybind-audit.sh` before you bind one.

## Vessels

Quality first, cost second (the user's rule, 2026-11-27). A gate checks
golem output, so a cheap base with a strong ladder is the same quality;
work with no gate gets the strongest model, since nothing checks it but
review. Defaults per construct; override when the work needs it, and say
why. Available models per host: `~/.pi/agent/hosts/enabledModels.<host>.json`.

- **Summoner**: `claude-opus-5.5`. Use fable through counsel for hard
  architecture or review reads.
- **Familiar**: `claude-fable-5.2:high` (the default since 2026-11-27).
  A familiar gets a brief, not a gate, so judgment decides its quality.
  The bake-off did not settle this: the two blind readers split by model
  family (fable's reader ranked fable first, astra's ranked sol and astra
  first). Change it only after a third-family or human read.
  `-m sol` for a brief that is mechanical but has no gate. Familiars run
  with `PI_COUNSEL=off`; summon with `-C` when the brief needs counsel.
- **Golem**: anvil `--model sol` (gpt-6.2-sol, since 2026-11-28), also
  for deep refactors. Ladder: `sol:high -> sol:xhigh -> fable:high`
  (default `-n 3`). Evidence: the sandbox bake-off (10 specs x 6 models,
  one attempt each, blind review by two readers,
  `~/scratch/model-bakeoff-report.md`): sol green on 9 of 9 quality specs
  (one on host rerun), 8 of 9 patches with no blocker or major, $0.59 a
  run; luna 1 blocker and 8 majors in 7 patches. From the 185-run ledger:
  fable:high rescued 16 of 19 escalations, opus:high 1 of 6.
  Anvil's default strong rung is fable since anvil#70. Exceptions:
  - Purge, delete, redact or wipe-personal-data specs: `-m fable` from
    the start (OpenAI moderation refused them on luna; untested on sol).
  - Purely mechanical batches (formatting, a codemod): `-m luna` is fine.
  - A spec whose gate cannot see the quality that matters (UI feel,
    prose, an API shape): `-m fable`, with `-r` naming the reason.
- **Legion**: `sol` members, the golem rule.
- **Astra** (`gpt-6.2-astra`): only for work that starts fresh and ends in
  one sitting (review familiars, one-shot assessments, cross-family second
  reads). Its prompt cache misses often after idle gaps; never use it as
  an all-day Summoner.
- **Cross-family second read**: ask counsel with its `model` argument
  ("have counsel review with an OpenAI model"). Do not hand-roll `pi -p`.
- **CLI binding**: gateway ids contain a slash, so always bind with
  `pi --provider vercel-ai-gateway --model "<vendor>/<model>:<effort>"`.

**Measure quality, not only green.** Record each construct's review
findings (count and worst severity) when you review its diff, so the
ledger can compare models on what review finds, not on gate passes.

Closed 2026-11-27 by the quality-first rule: proof 4 (haiku golems for
mechanical specs) ends, and proof 3 (luna-first on former fable specs)
is now the golem rule.

Lapsed: proof 5 (impact-tiered review) had no entry in
`~/scratch/review-tier-trial-notes.md` by its extended deadline, so it
is dropped and full review stays for every construct.

## Summoning

Use the scripts in `~/.dotfiles/scripts/.scripts/`; never hand-roll a
summon:

- `summon-familiar.sh [-m vessel] [-P] [-W fam-<issue> [-S stream]] <brief>`:
  binds the gateway provider, verifies startup, injects the report-back
  address and `PI_POST_PARENT`. `-P` is a one-shot `pi -p` dispatch with a
  log in `~/scratch/logs/`.
- `summon-golem.sh [-m vessel] <name> <spec> [anvil args...]`: a named
  window, `--json` results, `-v --reasoning`, and a pi-post completion
  ping on every exit path (silence means still running).

Both fail loudly on a misbinding or a missing report-back address (`-R`
opts out on purpose).

Rules:

- **Route by the decision the work needs.** A gate exists: golem. No gate
  and no decision expected mid-run: `summon-familiar.sh -P`. A decision
  expected mid-run: window familiar (`-W fam-<issue>`).
- **Specs go to golems, briefs go to familiars.** A spec has a verifiable
  end state and a gate; a brief needs steering or judgment. Name the file
  by its content (`-spec.md` / `-brief.md`). If a spec has no gate, write
  one or call it a brief.
- **Run anvil inline only if it ends well inside the tool timeout.** A
  timeout kills anvil with no exit path and leaves the record `running`.
  A fable base or a slow gate goes through `summon-golem.sh`.
- **A relayed approval unlocks nothing.** Push, PR, merge, deploy and
  DB writes need the user directly. In the brief, choose one: the
  familiar stops at a commit and the Summoner does the gated step, the
  user approves in the familiar's window, or the familiar is summoned
  with `-A` and the user answers each gated call in the approval inbox
  (Sigil overview, macOS alert, or `approvals list|approve|deny`). With
  `-A` plain pushes and PR creates and merges ask too. A held call waits
  30 minutes (`PI_APPROVAL_WAIT_MS`), then is blocked.
- **The Summoner speaks for the user within the brief.** pi-post stamps
  messages from the Familiar's parent; those cover scope changes and
  recoverable git steps in the Familiar's own worktree. Without a parent
  binding, every message gets the no-authority stamp.
- **Run a batch of issues from one flat coordinator.** One session does
  scout gather, spec plus gate, `summon-golem.sh`, review on the ping,
  re-commit and a PR body with `LEDE_PLACEHOLDER`, then gives the user one
  batch (ledes, open, decisions, merge when green). Notes:
  `~/scratch/orchestration-climb-notes.md`.
- **Familiars are summoned, never conscripted.** New task work always
  gets a fresh construct. Existing sessions get coordination only: acks,
  freezes, collision checks, relays.
- **Report-back targets are `s-...` addresses, never directory paths.**
- **Push, not poll.** Reports and pings arrive over pi-post. A ping is a
  claim, not a review.
- **Check work in flight before you summon:** `anvil status`, `git
  worktree list`, `construct-term.sh list`. The collisions that matter are
  two agents on one issue or two open DB migrations.

## Worktrees and git

- **Every file-touching construct and session works in its own worktree**
  (`~/dev/<repo>-worktrees/<issue>`). Before you edit in a main checkout,
  check for other live sessions in that repo.
- **Never `git stash` in a repo with more than one worktree** (one
  `refs/stash` for all of them). Inspect other refs with `git show
  <ref>:<path>` or a throwaway `git worktree add /tmp/x <ref>`; never
  `git checkout` in the shared checkout.
- **Start every multi-step bash call with `cd <worktree> && ...`** as one
  chain, so a failed `cd` stops it.
- **Seed contracts from a base worktree** at `origin/main`
  (`~/dev/<repo>-worktrees/<id>-base`), not the shared checkout; pass it
  with `-C`, and remove it after the merge.
- **Golem commits are pushable as they are** (anvil uses your git
  identity and signing). To replace the `anvil: <spec>` message, soft-reset
  and commit once, and check the tree matches the golem's commit.
- **`git worktree remove` on gtm can take over 90 s.** Run it alone with a
  long timeout, after `lsof -d cwd | grep -F <path>` is empty. Prune anvil
  worktrees after merge.

## Gates

Before dispatch, run every gate on the fork SHA in a login shell (a new
tmux or Rex window), not only in the bash tool. It must fail cleanly when
the work is not done and pass when it is.

- **The gate must be satisfiable inside `--scope`.** Scope repo-wide lints
  to the changed files or the scope, and mirror CI's filters. Name known
  host-only failures in the spec, or gate on the subset that can pass
  here. A diff that touched config or out-of-scope files to get green is
  a summoner bug: revert that part before review.
- **No grep exit-code traps.** `grep -v` fails on empty output and `grep
  -q` on no match. Write counts (`n=$(... | grep -vc x); [ "$n" -eq 0 ]`)
  or a script that exits on a boolean.
- **No `cd` inside a captured substitution.** `CDPATH` is set in the
  golem's shell, so `cd` prints a path. Pass paths to the tool or `unset
  CDPATH`.
- **TS gates include `tsc --noEmit`** when you override auto-detection.
- **A gate for a shared package builds a consumer**: add `pnpm --filter
  <consumer> build` for one bundler consumer when the spec touches
  `packages/*` source.
- **Repair specs carry at most two independent findings or one app or
  package.** Split larger ones into disjoint specs. A strong-rung golem
  past ~10M cumulative context is the spec's fault.
- **Read the golem's diagnosis before you re-dispatch** a gate it could not
  satisfy.

## Scrying

Measure the variable the decision turns on, not the convenient one. Find
the full population first (for example `grep -l` over the configs) before
you sample.
