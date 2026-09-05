---
description: Load a Linear issue and warm up context, then stop for direction
argument-hint: "<GTMENG-1234 | 1234 | linear.app URL> [extra context]"
---
Load Linear issue `$1` and warm up context. Do not start implementing; end with a
short report and wait for direction.

**Normalize the reference first.** `$1` may be a full identifier (`GTMENG-1234`),
a bare number (`1234`, assume team `GTMENG`), or a Linear URL
(`https://linear.app/vercel/issue/GTMENG-1234/<slug>`, take the `TEAM-N` path
segment). Use the normalized `TEAM-N` everywhere below. Anything after `$1` in
`$@` is extra context from me (a spec path, a constraint); read it too.

**Gather** (the `linear-cli` skill documents the CLI; it is `linearis`):

1. `linear issues read TEAM-N` (fall back to `--api-token "$LINEAR_API_KEY"` if
   `LINEAR_API_TOKEN` is unset). Include description, comments, relations,
   children, project, cycle, labels, assignee, state.
2. Prior art on this machine: `rg -n "TEAM-N|team-n" .bonfire/index.md`,
   `git branch -a | rg -i "team-n"`, `ls ~/dev/*-worktrees* 2>/dev/null | rg -i
   "team-n"`, `gh pr list --search "TEAM-N" --state all --limit 5`, and
   `ls ~/scratch | rg -i "team-n"` for specs, handoffs, or notes.
3. Only then read the code the issue points at, enough to know where things
   live and what already exists. Skim, do not audit.

**Report** (compact; I know the codebase):

- Title, state, assignee, project, labels; one-line scope in my words.
- Description asks, then comment asks, numbered separately when they differ.
- Existing artifacts found in step 2 (branch, worktree, PR, spec, bonfire notes)
  with paths.
- Where things live: the 3-6 files that matter.
- Open questions or ambiguities that would change the approach.
- Your recommended session shape: inline, familiar (brief), or golem (spec +
  gate), with one sentence why.

Then stop and wait.
