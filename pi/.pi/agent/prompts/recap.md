---
description: Recap current repo state for a fresh contributor
---
Recap the state of the current repository as if onboarding a fresh contributor.

Cover, concisely:

1. **Branch** — current branch, ahead/behind origin
2. **Working tree** — uncommitted changes (staged + unstaged), any untracked files worth noting
3. **Recent commits** — last 5 commits, one line each
4. **In-flight work** — from the branch, the working tree and the open PR for this branch; surface current state, blockers, and next priorities
5. **Constructs** — anything still running or unreaped for this repo: `git worktree list`, `~/.scripts/construct-term.sh list` (tmux and Rex), `anvil status --since 2d` (skip if `anvil` is absent), and `~/scratch/*handoff*.md` touched in the last 3 days. One line each; say "none" if none.
6. **Open issues / PRs** — only if obvious from `gh pr list` / `gh issue list` and only those assigned to me
7. **Linear** — only if there's evidence of Linear usage: a Linear-style branch name (e.g. `vieko/gtmeng-1182-...`), or a Linear ID in recent commits. If so, surface my started issues and the specific IDs found, read-only, with Linear MCP from one `codemode` script: `mcp__linear__list_issues({ assignee: "me", state: "started", fields: ["id", "title", "status", "project"] })` and `mcp__linear__get_issue` per ID (gotchas in the `linear-cli` skill). If MCP is not authenticated, fall back to `linear issues read <ID>`. Skip this section entirely when there's no such evidence.

Do not run anything destructive. Read-only commands only.
