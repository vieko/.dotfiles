---
name: monthly-checkin
description: Draft a personal monthly performance check-in from git history, authored PRs, issue-tracker work, project memory, and collaboration evidence. Use whenever the user asks to draft, prepare, update, review, or submit a monthly check-in, performance check-in, "what did you ship," or "where do you want to grow" response, even if they only name a month. Loads a private local profile for cadence, company context, voice, and examples; gathers evidence; and pauses before finalizing inferred collaboration or growth claims.
---

# Monthly check-in

Create a monthly performance check-in grounded in shipped work. Say what changed for the business, retain enough technical detail to be credible, credit substantive collaboration, and describe growth in the user's own terms.

The reusable workflow is public. Company context and real check-ins stay in a private local profile.

## Required private profile

Read `references/private-profile-setup.md` first. The skill requires these machine-local files by default:

```text
~/.config/monthly-checkin/config.json
~/.config/monthly-checkin/profile.md
~/.config/monthly-checkin/voice.md
~/.config/monthly-checkin/golden-example.md
```

If any are missing, stop and help create them from the provided templates. Never copy private profile contents, generated evidence, or real check-ins into this skill directory or another public repository.

## Start here

1. Read the four private profile files.
2. Resolve the named period using the cadence in `config.json` and `profile.md`.
3. Run the evidence gatherer.
4. Read the generated evidence and project memory before drawing a narrative.

## Phase 1: Gather evidence

Run:

```bash
~/.agents/skills/monthly-checkin/scripts/gather-evidence.py YYYY-MM
```

The script reads its repo, cadence, output directory, and relevant project paths from the private `config.json`. It writes evidence under the configured output directory.

If today falls before the work window closes, label the result as a draft through today's date. Never describe an open period as complete.

## Phase 2: Read the evidence

Use all available sources, but understand what each proves:

- Authored merged PRs prove shipped code and provide a volume cross-check. Do not turn the response into a PR recap.
- Completed issues created by or assigned to the user expose intent and project grouping.
- The user's commits provide implementation detail when PR titles are too thin.
- Other authors' commits in the configured project paths reveal collaboration opportunities and shared outcomes.
- PR reviews prove review participation, not co-ownership by themselves.
- Project memory provides rollout state, production measurements, reversals, incidents, and why the work mattered.
- Existing check-ins are voice and continuity references, not evidence for a new claim.

For important or ambiguous work, inspect the PR body, commit body, changed files, and relevant project-memory section. Counts are supporting texture only. Check the evidence window before attributing any item to the month.

## Phase 3: Turn evidence into outcomes

Cluster the work into two to four outcomes informed by the private profile. For each cluster, determine:

1. What changed for a user, operator, or the business?
2. What technical mechanism made it possible?
3. What production evidence supports the claim?
4. What did the user specifically own?
5. Who owned a complementary part?

Lead with the first answer. Use the next two as proof. Use the last two to make ownership accurate.

## Phase 4: Collaboration pass

Actively look for collaboration before drafting. A good collaboration highlight has:

- one shared outcome;
- a specific part the collaborator owned;
- a specific part the user owned;
- a real seam where the work met;
- a reason the partnership improved the result.

Name a collaborator only when complementary ownership or substantive joint work is supported. Routine approval is not enough. Use cautious language such as "worked alongside" when the evidence shows connected parallel work but not close pairing.

Avoid both failure modes:

- claiming shared work as a solo accomplishment;
- diluting the user's contribution with a generic list of names.

Use the private golden example as the voice and attribution model.

## Phase 5: Draft "What did you ship?"

Start with one bold BLUF: a direct claim about what changed. Do not start with "I brought value," "I demonstrated ownership," or a list of projects.

Then write compact paragraphs that combine:

- business or operator consequence;
- enough technical detail to make it credible;
- production proof where available;
- concrete collaboration where earned.

End with a short synthesis. Include PR and completed-issue counts only as final supporting texture when useful.

Recommend a rating from the options in the private profile, but distinguish evidence from judgment.

## Phase 6: Develop "Where do you want to grow?"

Do not infer a personal growth goal and silently write it as fact. Repository evidence can suggest possibilities, but the user decides what they want to grow toward.

A complete growth answer contains:

1. the capability the user wants to develop;
2. the concrete products or outcomes where they will practice it.

A list of future deliverables alone does not answer the question. Before finalizing, offer two or three concise, evidence-grounded growth framings and ask which is true. If the user has already stated the growth direction, use it rather than interviewing again.

## Phase 7: Report before applying

Before writing the canonical draft, report:

- check-in month, evidence window, and due date;
- whether the period is closed or still open;
- proposed rating;
- two to four headline outcomes;
- credible collaboration highlights and confidence;
- proposed growth framings;
- claims that are inferred rather than proven.

Wait for confirmation when collaboration or growth remains uncertain. Do not ask again about facts already resolved in the conversation.

## Phase 8: Write the draft

Write the confirmed draft under the private profile's configured output directory using this shape:

```markdown
# [Month] [Year] monthly check-in

**Check-in window:** [start]-[end]

**Due:** [date]

**Status:** Draft through [date]; the window remains open through [date].

**Performance: [rating]**

## What did you ship?

**[Direct claim about what changed.]**

[Business outcome, technical mechanism, production proof, and collaboration.]

## Where do you want to grow?

[Capability the user wants to develop.]

[Concrete products or outcomes where they will apply it.]
```

Omit `Status` when the evidence window is closed. Preserve a submitted version before revising it.

## After submission

When the user shares what they actually submitted, update the private `golden-example.md` if it is a better or newer voice anchor. Submitted text outranks an agent-written draft.
