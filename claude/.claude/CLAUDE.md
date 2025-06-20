## Git Workflow

- **Commit Messages**: Follow Conventional Commits format
  - Format: `<type>[optional scope]: <description>`
  - Examples: `feat: adds user profile`, `fix(auth): resolves login issue`
  - Types: feat, fix, docs, style, refactor, test, chore, perf
  - Do not include "Generated with" or "Co-Authored-By" lines in commit messages

## Filesystem Operations

- When working with directories or files that have special characters like
  parentheses (e.g., `(dashboard)`):
  - For Bash commands, always use single quotes: `mkdir -p 'src/app/(dashboard)/lists'`
  - Avoid using escaped paths like `src/app/\(dashboard\)/lists` as they can cause syntax errors
  - For `touch` or other commands, also use quotes: `touch 'src/app/(dashboard)/lists/page.tsx'`
  - When using GlobTool, quotes aren't needed: `GlobTool({ pattern: "src/app/(dashboard)/**" })`
