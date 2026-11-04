---
description: Review a GitHub PR end-to-end
argument-hint: "<PR-URL or #N>"
---
Review GitHub PR $1.

Use `gh pr view $1 --json title,body,author,state,mergedAt,reviewDecision,baseRefName,headRefName,additions,deletions,changedFiles,files,reviews,statusCheckRollup` and `gh pr diff $1` to gather context. If the PR is already merged or closed, say so in the first line and stop unless I asked for a post-merge review.

Report:

1. **Scope** — one sentence: what does this change do, and for whom?
2. **Worth it** — one sentence: does the value justify the change and its
   maintenance cost, or does the base already solve this? Say "yes" plainly
   when it does.
3. **Risk** — low / medium / high, with justification
4. **CI status** — passing? if not, which checks are broken?
5. **Code review** — apply the criteria from `/review`:
   - correctness, type safety, side effects, security, API design
   - missing tests
   - scope: code, tests, or guards the stated intent does not need
   - give each finding a severity (`blocker` / `should` / `nit`, as defined in
     `/review`) and the format `<severity> <file>:<line> <claim>. Fix: <suggestion>`
6. **Approval recommendation** — `Approve` (nits at most), `Request changes`
   (any blocker or should), or `Needs discussion`

If the PR touches infra/auth/billing/migrations, flag that prominently as a separate
"High-risk surface" callout regardless of code quality.

**Next step.** End with lettered options, the recommended one marked, for what
to post. My usual answer is "approve (or request changes), inline the
findings for <author>'s agent to pick up, and draft me a Slack one-liner", so
make that option concrete:

- the review verdict to submit;
- each inline comment as it would be posted: one short sentence per
  finding, at its `file:line`, written so the author's coding agent can act
  on it without the rest of this report (no severity essay, no restating
  the diff);
- a Slack one-liner to the author in my voice (`~/private/profile/slack-voice.md`):
  the verdict and the one thing they need to do, by name.

Do not submit the review, post comments, or merge until I pick an option.
