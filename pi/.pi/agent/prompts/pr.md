---
description: Review a GitHub PR end-to-end
argument-hint: "<PR-URL or #N>"
---
Review GitHub PR $1.

Use `gh pr view $1 --json title,body,author,baseRefName,headRefName,additions,deletions,changedFiles,files,reviews,statusCheckRollup` and `gh pr diff $1` to gather context.

Report:

1. **Scope** — one sentence: what does this change do?
2. **Risk** — low / medium / high, with justification
3. **CI status** — passing? if not, which checks are broken?
4. **Code review** — apply the criteria from `/review`:
   - correctness, type safety, side effects, security, API design
   - missing tests
   - scope: code, tests, or guards the stated intent does not need
   - give each finding a severity (`blocker` / `should` / `nit`, as defined in
     `/review`) and the format `<severity> <file>:<line> <claim>. Fix: <suggestion>`
5. **Approval recommendation** — `Approve` (nits at most), `Request changes`
   (any blocker or should), or `Needs discussion`

If the PR touches infra/auth/billing/migrations, flag that prominently as a separate
"High-risk surface" callout regardless of code quality.
