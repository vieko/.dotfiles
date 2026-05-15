---
description: Review staged git changes
---
Review the staged diff (`git diff --cached`). Be specific and honest — flag issues, don't praise.

Focus on:

- **Correctness** — bugs, logic errors, missing edge cases
- **Type safety** — `any` introductions, lost narrowing, broken generics
- **Side effects** — async without awaits, missing error handling, unhandled rejections
- **Security** — injection paths, credential leaks, path traversal, prototype pollution
- **API design** — naming, surface area, hidden coupling, breaking-change risk
- **Tests** — what coverage is missing for the new behavior
- **Commit message** — does it accurately describe the change? Conventional commits scope?

Don't comment on style/formatting if a linter would catch it.

End with one of: `LGTM`, `Minor nits — fixable in-line`, or `Needs revision — see above`.
