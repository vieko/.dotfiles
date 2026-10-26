---
name: revisit-pr
description: Bring a stale pull request up to date and decide whether it should still exist. Use when the user asks to freshen up, bring up to speed, catch up, or rebase a PR or branch that has fallen behind its base.
---

# Revisit PR

Revisit the idea, not only the branch. A clean rebase does not prove the PR
still belongs in the product.

Adapted from [t3dotgg/tstack](https://github.com/t3dotgg/tstack) (MIT), with
this machine's push and merge rules.

## Guardrails

- Fetch first: the PR head, its base, and any related branch.
- Treat uncommitted work in the current worktree as the user's. If the
  worktree is dirty or busy, work in a disposable worktree.
- A revisit authorizes a local rebase. It does not authorize merging,
  closing the PR, changing its base, or growing its scope.
- A rebased branch needs a force push, and the destructive command guard
  applies: ask before pushing unless the user asked to push in this turn.
  Push only with `--force-with-lease=<branch>:<head sha seen before rebase>`,
  never a bare `--force`.
- Do not post a PR comment unless the user asked for one.

## 1. Establish intent

Record the PR URL, state, base, head branch, head SHA, author, checks, and
review state. Read the title, body, linked issues, commits, review threads,
and the full diff. State the smallest goal the PR was trying to reach before
you judge its implementation. Record the merge base, so the PR's own changes
and later base changes stay separate.

## 2. Check what changed around it

Read the base commits since the merge base. Search merged and open PRs that
touch the same paths or the same behavior. Look past overlapping lines:

- Did the base already solve the same user-facing problem?
- Did APIs, types, schemas, dependencies, or boundaries change?
- Do both sides now own the same behavior or invariant?
- Was the code this PR changes deleted, moved, or simplified on purpose?
- Would landing it restore old behavior or add a second way to do one thing?
- Is the benefit still worth the maintenance cost?

No Git conflicts does not mean the PR is current.

## 3. Choose a disposition before touching the branch

- **REFRESH** — the goal is still useful and the shape is still right.
  Rebase, resolve, check, and (with permission) push.
- **REWORK** — the goal is still useful, but a mechanical rebase keeps the
  wrong implementation. Describe the smallest credible rewrite and stop,
  unless the user also asked for the rework.
- **CLOSE** — superseded, obsolete, wrong direction, or not worth its cost.
  Cite evidence and stop. Never close it without explicit permission.

Age alone is not evidence. Sunk effort is not a reason to keep a PR alive.

## 4. Rebase without losing intent (REFRESH only)

1. Create a local branch or disposable worktree at the recorded head SHA.
2. Rebase onto the freshly fetched base.
3. Resolve each conflict by the PR's intent and the base's newer invariants.
   If a conflict shows a product or architecture disagreement, stop and
   reconsider the disposition instead of guessing.
4. Compare the series with `git range-diff <merge-base>..<old-head> <new-base>..HEAD`
   and read the final diff. Confirm no intended behavior disappeared and no
   already-landed behavior came back.
5. Run the repo's focused checks for the touched area. Separate real failures
   from pre-existing or infrastructure failures.
6. Push per the guardrails. If the lease fails, fetch and reassess; do not
   overwrite new work.

## Report

Lead with `REFRESH`, `REWORK`, or `CLOSE` and the reason. Then give the
meaningful base changes, conceptual conflicts (or "none found"), the rebase
and push result, checks run with results, and the remaining decision with the
PR link. Separate observed facts from judgment, and say what you could not
verify.
