---
name: performance-mock-review-panel
description: Simulate the reviews Vieko will receive in a Culture Amp cycle — mock peer reviews, a mock manager review with a rating prediction, and a synthesis of themes and blind spots. Use when the user wants to rehearse, red-team, or predict their incoming reviews or rating. Not for writing reviews the user gives to others, or their own self review.
disable-model-invocation: true
---

# Mock Review Panel

Simulates the reviews Vieko will *receive* in a cycle, from the reviewers' vantage
points. The output is a set of mock review documents plus a synthesis — a rehearsal
of what's coming, so nothing in the real results or the calibration conversation
lands as a surprise.

## Stance: adversarial honesty

A mock review that reads like praise is useless. The value of this exercise is in
the critiques, the "want to see more of" answers, and the visibility gaps — work
Vieko values that a given reviewer simply never saw. Weight those. When in doubt
between a generous reading and a skeptical one, write the skeptical one; the real
reviews can only be pleasant surprises from there.

At the same time, honesty cuts both ways: don't invent negatives any more than
positives. Every substantive claim must trace to evidence or be explicitly labeled
as inference (see Grounding, below).

## Current cycle context (H2 FY27)

- **Review period:** Feb 1, 2026 → July 31, 2026.
- **Panel (confirmed by Vieko):** peers Reed Klaeser, Cameron Youngblood, Joe Reitz;
  manager Drew Bredvick.
- **Peer questions:** use the real template at
  `~/private/reviews/h2-fy27-peer-review-template.md` — mock reviewers answer
  exactly those questions, including the sharing-rule split (Q1/Q2 manager-only,
  Q3 shared with name attached). A realistic reviewer writes Q1/Q2 more candidly
  than Q3; the mock should reflect that asymmetry.
- **Rating prediction:** explicitly requested for this cycle. See the manager-mock
  section for the rules.

For a new cycle, update this section: new panel, new period, new template path
(`~/private/reviews/<cycle>-peer-review-template.md`), and re-confirm whether a
rating prediction is wanted.

## Evidence sources

Read before drafting:

- `~/private/profile/voice.md` — for the synthesis doc only. Mock reviews are
  written in each *reviewer's* plausible register, not Vieko's.
- `~/private/checkins/` and `~/private/checkins/evidence/2026-02..2026-08.md` —
  what actually happened this period. Filter to the official window.
- `~/private/reviews/h2-fy27-self-review-submitted.md` — what Drew will read.
- Reviews Vieko wrote about panel members (e.g.
  `h2-fy27-peer-review-given-cameron-youngblood.md`) — these document the shared
  seams from Vieko's side and are the best proxy for what that peer saw.
- `~/private/profile/job-leveling-framework.md` — manager-mock calibration.
- `~/private/profile/manager-job-description.md` — background on how Drew is
  incentivized to evaluate, not evidence of anything.
- `~/private/reviews/performance-review-rating-scale.md` — the official score
  definitions the rating prediction must be phrased against.

## The visibility filter (the core mechanic)

Each mock reviewer can only write about what they plausibly *saw*. This is the
peer-review skill's collaboration-only filter, inverted: instead of asking "what
did we do together," ask "what of Vieko's work crossed this person's field of
view?" A peer who only touched one project can only review that project — and if
the resulting mock is thin, that thinness is itself a finding (it predicts a thin
real review, and flags a visibility problem to fix next cycle).

Never pad a thin reviewer's mock with work they couldn't have seen, even if it's
Vieko's best work of the period.

## Step 1: Per-reviewer visibility interview

For each panel member, establish the seams before drafting. Where a prior
review-given exists (Cameron), start from it and confirm it still covers the
shared surface. Where none exists (Reed, Joe), interview Vieko:

> - What did you and [name] work on together this period? Which projects, channels, seams?
> - What of your work did they see the results of, even if you didn't collaborate directly?
> - Any friction, disagreement, or dropped ball between you two? (This is where real Q2 answers come from.)
> - What would [name] say your default failure mode is?
> - How does [name] write? Terse, effusive, structured, blunt?

Ask about all peers in one message. Don't draft any mock from guesses about an
unestablished seam.

## Step 2: Draft the mock peer reviews

One file per peer. Answer the real template questions in that reviewer's plausible
register and vantage:

- **Q1 (what did you work on together, impact):** only visibility-filtered work.
  Concrete and dated where evidence allows.
- **Q2 (want to see more of):** the heart of the mock. Derive it from real
  friction, from what the reviewer's own priorities are, and from what Vieko's
  failure modes look like *from their seat*. Generic answers ("keep doing what
  you're doing") are a drafting failure — a real peer under a text box produces
  at least one concrete ask.
- **Q3 (direct feedback):** apply the candor asymmetry — this is the name-attached
  section, so realistic reviewers soften or trim here.

### Grounding section (required in every mock file)

The review body must read as a review — no inline hedging or brackets. Below it,
add a `## Grounding` section: one bullet per substantive claim, each marked either
**evidence** (with source: check-in month, review-given file, thing Vieko said in
the interview) or **inferred** (with the reasoning). This keeps the simulation
auditable without polluting the rehearsal read.

## Step 3: Draft the mock manager review

Draft this *after* the peer mocks, because Drew's real review is informed by the
real peer reviews (he sees Q1/Q2) and by the submitted self-review. Inputs, in
order of weight:

1. What Drew directly observed: 1:1 surface, check-ins, Slack-visible outcomes —
   interview Vieko for this vantage the same way as for peers.
2. The submitted self-review (he reads it; assume he cross-checks its claims).
3. The mock peer reviews from Step 2, standing in for the real ones.
4. The leveling framework — calibrate observed scope/impact against Vieko's level
   expectations, next-level expectations where relevant.

Structure: impact summary as Drew would frame it, strengths, growth areas, then
the rating prediction. Same Grounding section requirement.

### Rating prediction rules

Vieko opted into a rating prediction for this cycle, knowing it is speculative.
Contain it properly:

- Phrase the prediction against the official definitions in
  `performance-review-rating-scale.md` — name the predicted score, quote or
  closely paraphrase the definition it maps to.
- Give a confidence level and the *rationale*: which evidence pulls toward the
  prediction, which pulls away.
- List the movers: "what would move this up one notch" and "what would move it
  down" — these are the actionable output, more useful than the number itself.
- Label the whole block `> ⚠️ Speculative prediction — not information about the
  actual rating.` at the top.

This prediction exists only inside this skill's output. Never carry it into the
self-review skill's territory: the no-suggestion rule for Vieko's own numeric
self-rating stands absolutely, and a mock prediction is not a loophole around it.

## Step 4: Synthesis

One roll-up file, written in Vieko's voice (this one is *for* him, per
`voice.md`):

- **Recurring themes** across the mocks — anything two or more reviewers converge
  on is the highest-confidence prediction in the whole exercise.
- **Blind spots** — work from the check-in record that *no* panel member can see.
  This is the structural finding: it predicts systematic under-representation in
  the real cycle.
- **Per-reviewer read** — one line each: how strong is their visibility, what's
  their likely headline, what's their likely critique.
- **Prep moves** — concrete actions before results land: context worth raising in
  the next 1:1, claims in the self-review worth reinforcing with links, questions
  to bring to the results conversation, and visibility fixes for next cycle.

## Step 5: Present, then save

Show each mock in chat before writing files, leading with:

> ⚠️ These are simulations — predictions of what reviewers might write, not
> information about what they wrote. Treat divergence from the real reviews as
> the interesting data, not as an error.

After Vieko has reacted (corrections to seams, register, or missed friction),
save to `~/private/reviews/mock/`:

- `h2-fy27-mock-peer-review-from-<firstname-lastname>.md` (one per peer)
- `h2-fy27-mock-manager-review-from-drew-bredvick.md`
- `h2-fy27-mock-review-synthesis.md`

## Containment rules

- Everything stays under `~/private/` — never copy mock content into repos,
  Slack drafts, or anywhere public.
- Mocks are predictions, not sources. Never cite a mock file as evidence in the
  self-review, peer-review, upward-review, or check-in skills — not even after
  the real reviews arrive. Real evidence only, always.
- When the real reviews land, the useful follow-up is a diff conversation
  ("what did the mocks miss and why"), which sharpens next cycle's simulation —
  offer it, don't force it.
