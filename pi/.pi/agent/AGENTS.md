# Global Agent Instructions

These apply to every Pi session. Project-level `AGENTS.md` and `CLAUDE.md` override
or extend these.

## Session memory

This machine uses **Bonfire** for cross-session, cross-agent project memory.
It lives in `<project>/.bonfire/index.md` (NOT `.sessions/`).

Bonfire 7.0 is a file convention + per-host adapters — no rituals to run. The
file is kept current automatically by:

- **Pi adapter** (`~/dev/bonfire/pi/`, published as
  `github.com/vieko/bonfire` and loaded via the `packages` array in
  `~/.pi/agent/settings.json`, currently pinned to `@v7.3.1`). Hooks
  `session_compact` for rich Goal/Progress/Next/Blocked summaries and
  `session_shutdown` for a first-user-prompt fallback when compaction is
  broken or doesn't fire. Note: this runs the tagged release from GitHub,
  not your local working copy. To test in-flight changes, either bump and
  retag, or temporarily swap the entry for a local path / restore a dev
  symlink under `~/.pi/agent/extensions/`.
- **Claude Code adapter** (`~/dev/bonfire/claude/`, wired via a `Stop` hook in
  `~/.claude/settings.json`). Reads `ai-title` entries from the session JSONL.
- **Skill fallback** (`/skill:bonfire end`) for Codex / OpenCode / any agent
  without a native adapter. The skill has `disable-model-invocation: true`,
  so it never autoloads — invoke explicitly only when needed.

Opt in per repo with `mkdir <repo>/.bonfire`. Without that directory, all
adapters and the skill exit silently — globally configured hooks don't
pollute random projects.

The old `/skill:bonfire start` and `/skill:bonfire handoff` commands are gone.
`start` was redundant (cwd discovery already loads `.bonfire/index.md`).
Handoff is better served by Pi's first-party `handoff` extension, by Linear,
or by `pi @file` injection of a notes file.

Pi's own session tree (`/tree`, `/fork`, `/resume`) is for replaying conversation
history. Bonfire is for portable project memory across agents/days/contributors.
They are complementary, not redundant.

## Delegating autonomous work

For complex multi-step refactors, large rewrites, or anything that wants to run
unattended for a while: use the `forge` skill rather than doing it inline.
Forge is the verification-boundary delegate; this is a focused interactive shell.

**Never spawn `claude -p` in tmux to run forge.** Use the forge CLI directly
(or the forge MCP tools); the `claude -p` wrapper-in-tmux pattern bypasses
forge's verification boundary.

## PHYREXIA session lexicon (this machine)

Personal multi-agent naming for this host -- **not a team convention**. A
**Summoner** (the directing session, Pi or Claude Code) scopes work and
delegates to **Familiars** (same-runtime workers) and **Golems** (Anvil runs). Use this vocabulary when coordinating
multi-session work. Source of truth (topology + full role defs):
`~/.dotfiles/PHYREXIA.md` -- read it before summoning.

## Commit message style

Lowercase imperative with conventional-commits scope:

- `feat(scope): description`
- `fix(scope): description`
- `chore(scope): description`
- `docs(scope): description`
- `refactor(scope): description`

Body wraps at ~72 chars. Explain *why*, not what. Reference issues by `#N`
when applicable.

## PR announcements

When you open a PR, end your reply with three artifacts (this is the
cross-repo personal default; repo-level `AGENTS.md` may extend or
override):

1. **PR title + URL** on their own lines, for quick scanning.
2. **Pitch**: one sentence answering "what does this PR bring to the
   table?" — state the user-visible behavior change or capability
   unlocked, not a file-by-file recap. Call out flag-gated /
   dark-shipped PRs explicitly in the same sentence.
3. **Slack one-liner** (paste-ready, markdown link form):

   ```
   :pr: [verb(PROJECT): title (LINEAR-ID)](pr url) `+xxx` `-xxx`
   ```

   - `verb` is the conventional-commits type (`feat`, `fix`, `chore`,
     `docs`, `refactor`).
   - `PROJECT` is the Linear project name in ALL CAPS with spaces
     (e.g. `LEAD AGENT`, `PROMPT BENCH`, `VOLTRON`). For work without
     a Linear issue, fall back to the conventional-commits scope
     uppercased with hyphens-to-spaces (e.g. `AGENTS`, `LEAD WEB`).
   - Drop the `(LINEAR-ID)` chunk entirely when there's no Linear issue.
   - `+xxx` / `-xxx` are `additions` / `deletions` from
     `gh pr view <n> --json additions,deletions`.

Don't substitute a longer recap for the pitch — the pitch + one-liner
are the deliverables; anything else is supplementary.

## Tool & review notes

- **`linear` CLI quirk**: `linear issue view -j` omits the `labels` field entirely. Default-checking `.labels.nodes` returns `[]` even when labels are attached. Verify label assignments via the UI or a raw GraphQL query, not the CLI's `-j` output.
- **`linear issue update` is unreliable — prints `✓ Updated issue` while silently no-op'ing.** Observed for both `--state <name>` (resolves the state by name across the *entire workspace* and can bind to the wrong team's same-named state, e.g. "Done") and `--description`/`--description-file` (drops the body change entirely). Mutate deterministically via the API instead: `linear api 'mutation { issueUpdate(id: "<issueUUID>", input: { stateId: "<stateUUID>" }) { success } }'`. Fetch the issue UUID (and any state UUID) first via an `issues`/`workflowStates` query scoped to the team. For `description`, JSON-escape the markdown with `jq -Rs .` and inject it (`input: { description: $desc }`). Verify with a fresh API read — allow a few seconds for read-replica lag, since an immediate re-read can still show stale values.
- **PR review style on vercel repos**: keep JSDoc and code-comment prose tight. State what + why; the code shows how. Multi-paragraph explanations on small helpers read as noise — file-level headers documenting non-obvious context are fine.
- **Issue-tracker writing (Linear comments vs descriptions)**: the *description* is the canonical spec — put durable scope/design there. *Comments* are the decision trail (decisions, deltas, answers), not a place for analysis that really belongs in the description. Lead with the decision (BLUF: first line = takeaway / next action). Right-size to stakes: an ack is one line; a real fork (architecture, scope split) is verdict + 2–3 bullets + links — never an essay. Keep only the 1–2 non-obvious facts a future reader (human or agent) can't quickly re-derive, and cite files/IDs (`webhook/route.ts:565`, `GTMENG-1768`) over re-explaining. Long comments get skimmed past or truncated and cost agents context to re-ingest.

## Secrets

This machine resolves secrets at login-shell startup via 1Password `op inject`
from `~/.dotfiles/bash/env.op`. Resolved env vars are inherited by every shell
Pi spawns. Do not:

- look for `~/.secrets` (does not exist — migrated)
- `cat` or `source` any plaintext credential file
- attempt `op inject` from within agent tasks (will re-prompt for auth)

If a secret is missing, the source of truth is the `env.op` manifest. Add an
`op://` reference there.

## Destructive command guard

Agents must not invoke commands that overwrite or destroy local state without
explicit user instruction in the active turn. The most common traps:

### `vercel env pull` is forbidden

**Never run `vercel env pull`, `vercel env pull --overwrite`, or any variant.**
The command writes to `.env.local` by default and will clobber whatever is
there — including 1Password-injected values, locally-configured DATABASE_URLs,
feature flags, and dev-only overrides. The clobber is silent and complete; the
file is rewritten, not merged.

If an agent needs to know what env vars exist in a Vercel project, use
`vercel env ls` (read-only listing of keys + scopes, no values, no file writes)
or the Vercel dashboard. There is no legitimate agent-driven use case for
`vercel env pull` in this machine's setup — 1Password is the source of truth
for secrets and the dashboard is the source of truth for project config.

### Other destructive patterns

Similar discipline applies to:

- **Database migrations / schema mutations** — `pnpm db:migrate`, `db:push`,
  `drizzle-kit push`, `prisma db push`, raw `psql` writes against `DATABASE_URL`.
  These hit whichever DB the env points at. Default in many repos is
  production. Project-level `AGENTS.md` (e.g. `~/dev/gtm/docs/db/local-development.md`)
  has the per-project rules; the global principle is *never apply a migration
  the user did not ask for in this turn*.
- **Deployments** — `vercel deploy`, `vercel --prod`, `pnpm deploy`, anything
  that ships code beyond the local workspace. Never invoke without an explicit
  user instruction in the current turn.
- **Package publishes** — `npm publish`, `pnpm publish`, `bun publish`.
- **Force-push and history rewrites** — `git push --force`, `git push --force-with-lease`,
  `git reset --hard origin/...`, interactive rebase that would lose local commits.
  Always confirm with the user before any operation that could lose work.

Generating a migration *file* (`drizzle-kit generate`, `prisma migrate dev --create-only`)
is fine — the file is reviewable artifact. Applying it is the line.

When in doubt, ask. The cost of a confirmation round-trip is much smaller than
the cost of a clobbered `.env.local` or an unintended prod deploy.

## Shell behavior

Pi runs `bash -c` non-interactively. User shell aliases (`cat=bat`, `ls=eza`)
are **not** expanded. Use the POSIX command directly: `ls`, `cat`, `grep`,
`find`. Do not assume `bat`, `eza`, or `fd` are aliased — call them by their
real names if needed.

## Editor

`$VISUAL` and `$EDITOR` are `nvim`. Ctrl+G opens the current input in nvim.
Generally prefer Pi's `edit`/`write` tools over spawning nvim.

## Cross-platform

This `AGENTS.md` covers both macOS and Linux setups (see `~/.dotfiles/CLAUDE.md`).
Use `$OSTYPE` or the exported `$USER_OS` (`macos`/`linux`) to branch when
platform-specific behavior is required.

## Maintenance notes

### vercel-plugin skills path (`current` symlink)

`settings.json` points the vercel-plugin skills at a stable `current`
symlink, not a version directory:

```
~/.claude/plugins/cache/claude-plugins-official/vercel/current/skills
~/.claude/plugins/cache/claude-plugins-official/vercel/current/.claude/skills
```

`current` -> the installed version dir (e.g. `0.43.0`), so `settings.json`
never changes on a plugin bump. BUT the symlink lives inside the
plugin-managed cache: a plugin update creates a new version dir and removes
the old one, which leaves `current` dangling (or clobbers it). Symptom: the
skill set shrinks at startup with no error.

Fix on plugin update — re-point the symlink (no `settings.json` edit needed):

```
cd ~/.claude/plugins/cache/claude-plugins-official/vercel
ln -sfn "$(ls -d [0-9]* | sort -V | tail -1)" current   # newest version dir
```

Caveat: `current` is NOT tracked in dotfiles (it lives in the runtime cache),
so a fresh machine must recreate it after the plugin installs — add the
`ln -sfn` above to the deployment checklist / bootstrap.
