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
  `~/.pi/agent/settings.json`, currently pinned to `@v7.3.0`). Hooks
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
     (e.g. `LEAD AGENT`, `PROMPT BENCH`, `VOLTRON`). For unticketed
     work, fall back to the conventional-commits scope uppercased with
     hyphens-to-spaces (e.g. `AGENTS`, `LEAD WEB`).
   - Drop the `(LINEAR-ID)` chunk entirely when there's no ticket.
   - `+xxx` / `-xxx` are `additions` / `deletions` from
     `gh pr view <n> --json additions,deletions`.

Don't substitute a longer recap for the pitch — the pitch + one-liner
are the deliverables; anything else is supplementary.

## Tool & review notes

- **`linear` CLI quirk**: `linear issue view -j` omits the `labels` field entirely. Default-checking `.labels.nodes` returns `[]` even when labels are attached. Verify label assignments via the UI or a raw GraphQL query, not the CLI's `-j` output.
- **PR review style on vercel repos**: keep JSDoc and code-comment prose tight. State what + why; the code shows how. Multi-paragraph explanations on small helpers read as noise — file-level headers documenting non-obvious context are fine.

## Secrets

This machine resolves secrets at login-shell startup via 1Password `op inject`
from `~/.dotfiles/bash/env.op`. Resolved env vars are inherited by every shell
Pi spawns. Do not:

- look for `~/.secrets` (does not exist — migrated)
- `cat` or `source` any plaintext credential file
- attempt `op inject` from within agent tasks (will re-prompt for auth)

If a secret is missing, the source of truth is the `env.op` manifest. Add an
`op://` reference there.

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

### Version-pinned skills path

`settings.json` references the Claude vercel-plugin skills via a hard-coded
version directory:

```
~/.claude/plugins/cache/claude-plugins-official/vercel/0.42.1/skills
~/.claude/plugins/cache/claude-plugins-official/vercel/0.42.1/.claude/skills
```

When the plugin updates, this path goes stale and Pi silently loads zero
skills from it. Symptom: the skill set shrinks at startup with no error.
Fix: bump the version segment in both entries to match whatever
`ls ~/.claude/plugins/cache/claude-plugins-official/vercel/` reports.
Long-term: replace with a symlink (e.g. `vercel/current`) once the plugin
cache layout stabilizes.
