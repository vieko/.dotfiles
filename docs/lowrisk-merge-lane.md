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

1. Pick the repos. Start with the user's own repos (dotfiles, anvil,
   bonfire, sigil), not `vercel/gtm`, which requires a Slack post and
   review approval.
2. Turn on "Allow auto-merge" in each repo's GitHub settings.
3. After the SHIP verdict and a QUALIFIES result, run the printed
   `gh pr merge <n> --auto --squash`. GitHub merges when checks pass.
4. Log each lane merge in `~/scratch/review-tier-trial-notes.md`. Revert
   to full review on the first lane merge that needs a follow-up fix.

## CI autofix

Claude Code's CI autofix lets the authoring session see a failed check
and push a fix. The equivalent here: dispatch `pr-wait.sh <pr> --detach
--notify` from the authoring session. The red-check notification returns
to that session, and it fixes the failure before anyone reviews.
