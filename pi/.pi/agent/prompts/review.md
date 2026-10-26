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

Hold the change to the smallest diff that meets its intent. Flag code, tests, or
guards the intent does not need. When you suggest a fix, prefer one that deletes
or narrows code over a new helper, option, cache, or lock.

Give every finding a severity, judged by impact, not by how it is phrased:

- **blocker** — the intended case is wrong.
- **should** — a real bug that callers will hit, within the change's intent.
- **nit** — everything else: other paths, rare cases, small perf costs, extra
  compatibility, style.

Format each finding as `<severity> <file>:<line> <claim>. Fix: <suggestion>`.

End with one of: `LGTM` (nits at most), `Minor nits — fixable in-line`, or
`Needs revision — see above` (any blocker or should).
