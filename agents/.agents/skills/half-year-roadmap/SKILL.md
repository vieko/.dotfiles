---
name: half-year-roadmap
description: Draft half-year (H1/H2) goals or a roadmap for leadership from monthly check-ins, issue-tracker boards, project memory, and the codebase. Use whenever the user asks to draft, plan, or report H1/H2 goals, a half-year or quarterly roadmap, "what do I want to accomplish next half," or a goals summary for a manager to preview to leadership. Produces a BLUF Slack/Notion-ready document of 3-5 goals, each with a done-when, in the user's check-in voice.
---

# Half-year roadmap / goals

Turn accumulated evidence into a short, BLUF goals document a manager can
hand to leadership. The output is claims with done-whens, not a project
recap. Sibling procedure to `monthly-checkin`; reuses its private profile.

## Required private profile

This skill shares the monthly-checkin private profile and adds one file:

```text
~/.config/monthly-checkin/config.json
~/.config/monthly-checkin/profile.md
~/.config/monthly-checkin/voice.md
~/.config/monthly-checkin/roadmap.md
```

`roadmap.md` holds company-specific paths, the audience, real BLUF and
proof-clause examples, and the observed edit pattern from previous cycles.
If it is missing, stop and help create it. Never copy private profile
contents, real goals, or company evidence into this skill directory or any
public repository.

## Audience

Leadership with technical knowledge, usually one hop removed (the manager
previews it). Technical detail is proof, not subject. Every goal must
answer: what changes, why now, and how we will know it happened.

## Phase 1: Gather evidence

Pull from four sources before drafting anything (paths in the private
profile):

1. **Monthly check-ins.** The "What did you ship" arc shows trajectory. The
   "Where do you want to grow" answers are the goldmine: recurring, unpaid
   growth statements are goals the user has already committed to in
   writing. Quote them back.
2. **Issue tracker**: the user's open issues (grouped by project), project
   states, target dates, leads, and any ratified RFCs or epics. Linear
   quirk: the CLI may report unauthenticated in non-interactive shells even
   when `$LINEAR_API_KEY` is set; fall back to raw GraphQL via curl against
   `https://api.linear.app/graphql` (get the user id from
   `{ viewer { id } }` first).
3. **Project memory** (`.bonfire/index.md` in the active repo): rollout
   state, what shipped vs what is gated, lessons learned (evals, soaks,
   reversals).
4. **Codebase pulse**: recent git log for the user, reports and assessments
   committed under docs.

## Phase 2: Cluster into goals

3-5 goals, no more. For each candidate cluster ask:

- What changes for a user, operator, or the business?
- What already-shipped groundwork makes the coming half the moment? "Every
  prerequisite shipped last half" is a strong leadership argument.
- What is the done-when? A goal without a falsifiable done-when is a wish.
- Is anything a net-new project rather than a feature of an existing one?
  Label it "(new project)" explicitly so nobody misreads it as a line item.

Fold *how the work gets delivered* (delegation, specs, quality gates) into
the relevant goal rather than making process its own goal. Explicitly name
what is NOT the user's in the period (other people's projects they only
interface with) in the working draft, even if it gets cut from the public
version.

## Phase 3: Draft in voice

Read the private `voice.md` and follow it, plus rules specific to this
artifact:

- Open with a one-line BLUF listing all goals as verb phrases. See the
  private `roadmap.md` for a real example.
- One compact paragraph per goal: today's pain, what changes, proof it is
  feasible, bold **done-when** at the end.
- Slack mrkdwn for the Slack version (*bold* with single asterisks); the
  same text works in Notion with a heading per goal.
- Compress past evidence into one clause per proof point rather than
  explaining the machinery. Real examples live in the private `roadmap.md`.

## Phase 4: Iterate, then record the as-posted version

Expect the user to merge, reframe, or trim goals; incorporate without
re-litigating. When the user shares what they actually posted, save it to
the location configured in the private profile, including:

- the one-liner as posted;
- the full document as posted;
- a "deltas from the agent draft" section noting what the user cut or
  rewrote. Those edits are voice signal: fold the pattern back into the
  private `roadmap.md` for the next cycle.

The as-posted version outranks the draft. Read the previous cycle's final
file and the private edit-pattern notes before drafting the next one.

## Future-project spin-offs

When a goal names a net-new project, write a kickoff spec into the repo's
project memory (e.g. `.bonfire/specs/<project>.md`) covering: the goal as
posted, why it is a separate project, shipped prerequisites, first moves,
and open questions. Reference it from the project-memory index so a future
session lands on it without archaeology.
