# Low-risk merge lane (spec, not enabled)

Source: Lydia Hallie, "Rethinking Claude Code Best Practices" (Anthropic,
AI Engineer, 2026-11-12). Anthropic gives every PR a first review by Claude
in a fresh context, with separate agents that verify each finding. Human
review then scales with risk: docs and copy changes need no person once
checks are green, product changes get one reviewer, and risky changes get
two. Low-risk PRs use GitHub merge-when-ready.

This lane is the PR-level form of PHYREXIA open proof 5 (impact-tiered
review). The standing invariant ("every construct's diff passes one review
pipeline") is unchanged until the user enables the lane.

## Status

Not enabled. `~/.scripts/pr-lowrisk-check.sh <pr>` is dry-run only. It
prints QUALIFIES or REFUSES and the merge command it would run. Proof 5
has no data rows (`~/scratch/review-tier-trial-notes.md`), and its
week-44 deadline has passed.

Since da78e7b, personal repos already merge on green: the user's word to
open the PR covers the merge. So the lane removes no human turn there,
and team repos keep their `merge it`. What the lane still adds is the
part Anthropic pairs with auto-merge: a fresh-context review before
merge, and a path check that keeps instruction and skill files out of the
no-human path. Use it, if at all, as a pre-merge step in personal repos.

## Qualifying PR

All of these hold:

- Every path is docs or copy: `*.md`, `*.mdx`, `*.txt`, `docs/`, `content/`.
- No path is a behavior path. Agents read instruction files, skills,
  specs, prompts and settings as behavior, so a docs-only diff can still
  change what agents do. Excluded: `AGENTS.md`, `CLAUDE.md`, `PHYREXIA.md`,
  `CHAOS.md`, `SKILL.md`, `.agents/`, `.claude/`, `.pi/`, `.github/`,
  `.bonfire/`, `skills/`, `prompts/`, `specs/`, contracts, migrations,
  `package.json`, lockfiles, `.env*`, settings JSON, `vercel.json`,
  `turbo.json`.
- Under 200 changed lines.
- Open, not a draft, every check green.
- A SHIP verdict from a fresh-context review: a one-shot review familiar
  from the other model family than the author
  (`summon-familiar.sh -P -m <other family>`). It gets the PR diff and no
  authoring context.

## Enabling (user decision)

1. Scope: personal repos only (dotfiles, anvil, bonfire, sigil).
   `vercel/gtm` requires a Slack post and review approval.
2. Before the personal-repo merge in `~/.pi/agent/AGENTS.md`, run the
   checker. On REFUSES, a behavior path is in the diff: get the user's
   word or a fresh-context SHIP before merging.
3. Optional: turn on "Allow auto-merge" and use the printed
   `gh pr merge <n> --auto --squash`.
4. Log each lane merge in `~/scratch/review-tier-trial-notes.md`. Revert
   to full review on the first lane merge that needs a follow-up fix.

## CI autofix

Claude Code's CI autofix lets the authoring session see a failed check
and push a fix. The equivalent here: dispatch `pr-wait.sh <pr> --detach
--notify` from the authoring session. The red-check notification returns
to that session, and it fixes the failure before anyone reviews.
