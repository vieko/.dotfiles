---
description: Draft the human lede for a PR (one sentence, value first, my voice)
argument-hint: "[PR #, URL, or nothing for the current branch] [audience or angle]"
---
Draft a lede for us to review: the opening line of the PR description, in my
voice. Target: `$@` (if empty, the current branch's changes; if a PR number or
URL, read it with `gh pr view` and `gh pr diff --stat`).

**What a lede is.** One sentence, occasionally two, that answers "what does this
PR bring to the table?" for a non-technical reader. It states the user-visible
behavior change or capability unlocked, not what files changed. BLUF: the first
clause is the takeaway. If the PR is flag-gated, dark-shipped, or a
foundation for a next PR, say so in the same sentence. It sits above the
AI-written body; it is the human "why."

**Voice rules** (from `~/private/profile/voice.md`; read it if you have not
this session):

- Lead with a claim, not a setup. Concrete consequence over abstraction.
- Plain register, short sentences. No em dashes; colons and periods land.
- No hedging, no marketing adjectives, no "this PR introduces". "This" or a
  bare verb is fine ("Restores...", "Stops...", "Brings...").
- Numbers when they exist (calls recovered, minutes saved, x-times faster).
- A light touch of personality is allowed when the change earns it, never
  forced.

**Ledes I have written** (match this register, not the topics):

- Restores 370 customer calls missed during migration including their account
  links, notes, and Salesforce records.
- Stops a single oversized Salesforce lookup from permanently killing an Index
  chat.
- This prevents double-posting to account channels during call ingestion: each
  Slack post is claimed once per event.
- Index chats with screenshots or files now work across follow-up messages,
  even when users leave and resume the session.
- Adds rules for call comments: who may write one, who may see them, and who may
  change or remove them. Nothing visible yet, that comes next.
- You can't cut what you can't measure: this puts attendee research on the
  telemetry so the next PR has a baseline.
- GTM Monorepo now typechecks on the TS7 compiler, 3.5x faster cold typechecks.
- When a Zoom recording ingest fails, the system now alerts engineering with the
  actual error.

**Output.** Give me two candidates, each one sentence, labeled A and B (B may
take a different angle: outcome vs. mechanism, or user vs. team). No preamble,
no explanation unless a fact in the diff is uncertain, in which case ask one
question. I will pick, edit, or say "doesn't sound like me", and then you
revise.
