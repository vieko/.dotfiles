---
description: Draft the human lede for a PR (one sentence, value first, my voice)
argument-hint: "[PR #, URL, or nothing for the current branch] [audience or angle]"
---
Draft a lede for us to review: the opening line of the PR description, in my
voice. Target: `$@` (if empty, the current branch's changes; if a PR number or
URL, read it with `gh pr view` and `gh pr diff --stat`).

**What a lede is.** One sentence that says what changes for the people who use
or run this, for a reader who has not seen the diff. Not what files changed,
not how we found the problem. It sits above the AI-written body, which already
has the mechanism, the history, and the numbers. If the PR is flag-gated,
dark-shipped, or a foundation for the next PR, add a short second sentence:
"Nothing visible yet, the UI comes next."

**Rules** (from my edits on ~90 past ledes; they override the signature moves
in `~/private/profile/voice.md`, which are for long-form):

- **Short.** Aim for 12-20 words; 25 is the hard limit. My own rewrites run
  ~21 words, your rejected drafts ~30. When in doubt, cut the clause after
  the colon or semicolon.
- **One fact.** The single most important change. Drop the backstory (dates,
  "since #4237", "on in production since September 4"), the second and third
  effects, and the reassurance clauses unless they are the point.
- **Verb first, plain verb.** Start with what the PR does: Adds, Fixes,
  Stops, Removes, Moves, Prevents, Ensures, Brings back, Drops. Or start with
  the user-visible subject and "now": "Deleting a call now redacts
  transcripts." Do not front-load a long "When X fails in Y," clause.
- **Facts, not story.** No metaphor ("a real front door", "new home"), no
  aphorism or contrast device ("used to be a hope; now it is a test"), no
  rhetorical verbs (unlocks, drives, owns, carries). Do not make a system the
  hero of the sentence when a plain statement works.
- **Plain words.** Name the product or feature a reader knows (Index, Lead,
  Quality, the review bot), not internal module names, unless the reader is
  engineering and the name is the point (`pr-wait`, `app-data-report`).
- **Numbers only when they are the value** ("all 259 lint warnings",
  "370 customer calls"). Not as decoration.
- No em dashes. No "This PR introduces".

**Your drafts vs. what I shipped** (learn the edit, not the topic):

- Draft: "Lead Agent gets a real front door: a route reference that fails the
  build if it drifts from the code, plus a working `/api/health` for the
  first time since #1030."
  Mine: "Adds a landing page for Lead Agent with a route reference and a
  working `/api/health` route."
- Draft: "Leads worked in Salesforce fall off the VDR queue for good, with
  the rollout flag that gated it since September 5 removed."
  Mine: "Leads worked in Salesforce fall off the VDR queue for good."
- Draft: "When a repo guard fails in Quality, typecheck, lint, and tests now
  still run. In #4237, one missing doc row skipped all of them."
  Mine: "Ensures typecheck, lint, and tests always run, even when a repo
  guard fails the Quality pass."
- Draft: "The model registry now refuses to pair a zero-data-retention
  request with a model that can't serve it: a construction-time throw
  instead of a 400 in production."
  Mine: "Requesting ZDR on a model that can't serve it now fails in a unit
  test."

**Ledes I wrote or shipped** (match this register):

- Restores 370 customer calls missed during migration, including their
  account links, notes, and Salesforce records.
- Stops a single oversized Salesforce lookup from permanently killing an
  Index chat.
- Deleting a call now redacts transcripts.
- Prevents every Vercel project in our monorepo from building on docs-only
  PRs.
- Brings back report titles, route suggestions, request rewrites, and
  launch-calendar matching to Feedback.
- Fixes a stale call-prep test that fails Unit tests on any PR touching a
  package `gtm-workflows` depends on.
- `pr-wait` no longer mistakes a fresh push for "no checks, all clear":
  every new head restarts the cycle.
- Moves the delete-a-call logic out of the operator script into a shared
  module Index can call. Nothing visible yet, the UI comes next.

**Output.** Two candidates, labeled A and B, each within the rules above. B
states the same fact from the other side (user vs. team, or outcome vs. the
change itself), at the same length and plainness; B is not the longer or
more colorful version. Before you send them, check each one silently (word count,
first word, no backstory, no metaphor); print only the two labeled
sentences. No preamble and no explanation,
unless a fact in the diff is uncertain; then ask one question. I will pick,
edit, or say what reads wrong. When I say "shorter", "hard to read", or
"less story", cut to the one fact and the plainest verb; do not rephrase the
same length.
