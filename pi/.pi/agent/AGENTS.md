# Global Agent Instructions

These apply to every Pi session. Project-level `AGENTS.md` and `CLAUDE.md` override
or extend these.

## Session memory

This machine uses **Bonfire** for cross-session, cross-agent project memory.
It lives in `<project>/.bonfire/index.md` (NOT `.sessions/`).

- Use the `bonfire` skill via `/skill:bonfire start` at session start to load context.
- Use `/skill:bonfire end` at session end to capture work.
- Use `/skill:bonfire handoff [description]` to queue a handoff for a fresh session.

Pi's own session tree (`/tree`, `/fork`, `/resume`) is for replaying conversation
history. Bonfire is for portable project memory across agents/days/contributors.
They are complementary, not redundant.

## Delegating autonomous work

For complex multi-step refactors, large rewrites, or anything that wants to run
unattended for a while: use the `forge` skill rather than doing it inline.
Forge is the verification-boundary delegate; this is a focused interactive shell.

## Commit message style

Lowercase imperative with conventional-commits scope:

- `feat(scope): description`
- `fix(scope): description`
- `chore(scope): description`
- `docs(scope): description`
- `refactor(scope): description`

Body wraps at ~72 chars. Explain *why*, not what. Reference issues by `#N`
when applicable.

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
