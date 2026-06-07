---
description: Recap current repo state for a fresh contributor
---
Recap the state of the current repository as if onboarding a fresh contributor.

Cover, concisely:

1. **Branch** — current branch, ahead/behind origin
2. **Working tree** — uncommitted changes (staged + unstaged), any untracked files worth noting
3. **Recent commits** — last 5 commits, one line each
4. **In-flight work** — read `.bonfire/index.md` if present; surface current state, blockers, and next priorities
5. **Open issues / PRs** — only if obvious from `gh pr list` / `gh issue list` and only those assigned to me
6. **Linear** — only if there's evidence of Linear usage: a Linear-style branch name (e.g. `vieko/gtmeng-1182-...`), a Linear ID in recent commits or `.bonfire/index.md`, or an authenticated `linear` CLI. If so, surface issues assigned to me via read-only `linear` commands (e.g. `linear issue list`, or view the specific IDs found). Skip this section entirely when there's no such evidence.

Do not run anything destructive. Read-only commands only.
