---
name: index-biweekly
description: Compose a recurring INDEX project update for Slack in Vieko's voice and format. Use this whenever the user asks to write, draft, compose, or update an Index project update, two-week or biweekly Index report, "Index this week" update, or recurring Index progress summary destined for Slack. Gathers merged work from git + the bonfire epic state across the whole Index surface (all contributors), then renders it as compact Slack mrkdwn with a TL;DR (value-first bullets, not a commit recap).
---

# INDEX — project update

A recurring project update summarizing everything that shipped on Index since the
last report (two-week cadence). Index is the GTM call-intelligence product: Zoom
capture, transcripts, insights, the Gong archive, listeners, call sharing, and the
Eve chat agent. The audience is GTM stakeholders plus engineering peers — they care
about *what changed for users or the business*, not the implementation. The output
is **raw Slack mrkdwn**, pasted directly into the channel.

This is a writing-style skill. The single most important reference is the golden
example — match its voice, rhythm, and structure before anything else.

**Read `references/golden-example.md` first.** It is the spec. Everything below
explains how to reproduce it for a new window.

Two things distinguish this from the LEAD AGENT update:

1. **It covers the whole project, all contributors** — not just Vieko's work. The
   gather sweeps every merge to the Index surface regardless of author.
2. **It is deliberately shorter.** A TL;DR line, ~5 shipped bullets, 3 what's-next
   bullets. If a draft reads like a release digest, cut it — merge adjacent themes
   into one bullet rather than adding more.

## The shape of the work

Two phases: **gather** (mechanical), then **compose** (judgment). Don't shortcut the
gather — the report's credibility comes from being grounded in real merged PRs and
the real project state, not vibes.

### 1. Gather

Establish the window first: two weeks by default. Pin the cutoff precisely — ask when
the last report went out or infer it from the previous post's date. Everything merged
*after* that cutoff is in scope; everything before is already reported and must not
be repeated.

Pull the merged work across the Index surface area:

```bash
git log origin/main --format="%h|%an|%ad|%s" --date=short --since="<cutoff>" -- \
  apps/index agents/index packages/index packages/listeners
```

`apps/index` (the app + Zoom client), `agents/index` (the Eve chat agent), and
`packages/listeners` are the core. Also check for Index-adjacent work that lives
elsewhere: Eve embeds in `apps/athena`, listener wiring in `apps/gtm-workflows`
(e.g. Zoom-ingest hooks). Include those when they change what Index delivers.

**Scope guard:** the events-registry plumbing (`packages/events` catalogs,
subscriber-as-code, freeze periods, cron producers) is its own project (VOLTRON /
events) — leave it out unless a change directly powers an Index-visible capability
(e.g. keyword listeners posting to Slack).

For any commit whose value isn't obvious from the subject line, read the PR body —
`gh pr view <n> --json body -q .body` — it usually carries the *why* and the numbers
(precision rates, coverage, user anecdotes) that make a bullet land.

Then read `<repo>/.bonfire/index.md` for the project narrative — what flipped live,
what's blocked, what's queued. Scoping specs in `~/scratch` (e.g. encryption scope)
are a legitimate What's-next source; flag them as inferred and confirm with the user.

### 2. Compose

Structure, in order:

1. `:update: :index: *PROJECT UPDATE*`
2. `_TL;DR: ..._` — one italic sentence, three or four clauses, the whole update in
   miniature. Write it last, from the bullets.
3. `*What shipped in the last two weeks*` — ~5 bullets
4. `*What's next*` — 3 bullets

## House style

The voice is the product. These rules reproduce it; the golden example shows it.

**Slack mrkdwn, raw.** Output the literal characters the user will paste:
- `_italic_`, `*bold*` (single asterisks — NOT `**bold**`), `` `code` ``
- Links as `[label](url)`
- Bullets are `* `, matching the posted Slack source exactly
- Section headings are bold sentence case, no trailing colon

**Punctuation:** literal em dashes (`—`) sparingly, for a meaningful turn in the
sentence; prefer a colon, semicolon, or comma when one reads more naturally.

**Value over mechanism — this is the whole game.** Each bullet answers "what changed
for users or the business?", with just enough mechanism to be credible.
- Yes: *"Calls with external participants now record and transcribe automatically,
  reducing the chance that important customer conversations go uncaptured"*
- No: *"Cloud recording auto-starts off the same participant signal as RTMS via
  getParticipantAutoStartReason"*

Implementation details that don't survive the cut: auth routing, SDK/model choices,
deterministic-vs-LLM staging, schema shapes, flag names. A single validated metric
(e.g. "~95% precision") is welcome texture; two per bullet is a digest.

**Collapse PRs into outcomes.** A seven-PR capture thread becomes one bullet. Polish
and hardening across many small PRs fold into a single closing bullet ("clearer
sharing controls, stronger monitoring, and playback recovery make the core
experience more dependable"). The reader counts outcomes, not commits.

**Whole-project voice.** Never "I shipped" — the update speaks for the project.
Don't attribute bullets to individuals.

**What's next:** three bullets, outcome-first, honest about gating dependencies.
Pull from bonfire, scoping specs, and stated PR out-of-scope notes; confirm inferred
items with the user before treating them as priorities.

## Output

Write the finished report to `<repo>/.bonfire/drafts/index-this-week.md` so it's a
reviewable artifact in the gitignored drafts area, then offer the clipboard one-liner:

```bash
pbcopy < <repo>/.bonfire/drafts/index-this-week.md
```

Present the raw mrkdwn in the reply too, so the user can eyeball it before pasting.

## After a real report ships

When the user tells you what they actually posted (it may differ from your draft —
they edit for voice), **update `references/golden-example.md` with the shipped
version.** The golden example should always be the most recent real post, so the
voice anchor never drifts from what Vieko actually publishes. This skill lives in
the dotfiles repo, so that's a normal `cd ~/.dotfiles && git add` + commit.
