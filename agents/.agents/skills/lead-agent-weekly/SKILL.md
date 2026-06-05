---
name: lead-agent-weekly
description: Compose the weekly "LEAD AGENT this week" status report for Slack, in Vieko's voice and format. Use this whenever the user asks to write, draft, compose, or update the LEAD AGENT weekly report, the "this week" Lead Agent update, the weekly Lead Agent status post, or any recurring Lead-Agent progress summary destined for Slack -- even if they don't say the exact phrase "this week." Gathers the week's merged work from git + the bonfire epic state, then renders it as raw Slack mrkdwn (value-first bullets, not a commit recap).
---

# LEAD AGENT — weekly report

A recurring Friday-ish status post summarizing everything that shipped on Lead Agent
since the last report. The audience is GTM stakeholders (MOPS, sales leadership, the
VDR team) plus engineering peers -- they care about *what each change unlocks*, not
the implementation. The output is **raw Slack mrkdwn**, pasted directly into the
channel.

This is a writing-style skill. The single most important reference is the golden
example -- match its voice, rhythm, and structure before anything else.

**Read `references/golden-example.md` first.** It is the spec. Everything below
explains how to reproduce it for a new week.

## The shape of the work

Two phases: **gather** (mechanical), then **compose** (judgment). Don't shortcut the
gather -- the report's credibility comes from it being grounded in real merged PRs and
the real epic state, not vibes.

### 1. Gather

Establish the window first. The report is weekly, so the default cutoff is ~7 days
back, but pin it precisely: ask the user when the last report went out, or infer it
from the previous post's date. Everything merged *after* that cutoff is in scope;
everything before is already reported and must not be repeated.

Pull the merged work across the Lead Agent surface area:

```bash
git log --format="%h %s (%ad)" --date=short --since="<cutoff>" -- \
  apps/lead-agent apps/lead-web apps/lead-bot \
  packages/lead packages/lead-agent-framework packages/lead-cs \
  packages/enrichment packages/bounty-scoring
```

`apps/lead-agent` + `apps/lead-web` + the `lead*` packages are the core. `apps/lead-bot`
feeds the LEAD BOT section when it has activity. Check `apps/api` / `apps/athena` only
if something there is Lead-Agent-adjacent (e.g. a shared DB table the queue reads).

For any commit whose value isn't obvious from the subject line, read the body --
`git show <hash> --stat` and the commit message often carry the *why* and the metrics
(eval deltas, cost numbers, FP rates) that make a bullet land.

Then read `<repo>/.bonfire/index.md`. This is where the epic narrative lives -- which
measurement windows opened/closed, which flags flipped, what's blocked, what's queued
next. The git log tells you *what merged*; bonfire tells you *what it means for the
epic* and feeds the intro line and WHAT'S NEXT. If the repo has no `.bonfire/`, ask the
user for the epic state instead.

### 2. Compose

Group the week's work into sections, in this order, **including only the sections that
have real content this week**:

1. `*LEAD AGENT*` — the scorer/gates/model core (classification, gates, model swaps, region, reliability)
2. `*VDR DASHBOARD*` — the review UI/queue surface
3. `*OUTREACH DELIVERY*` — the send pipeline + rollout work
4. `*LEAD BOT*` — the Slack feedback/Linear-ticket agent
5. `*LEAD LOGS*` — the lead-agent-log channel / logging surface
6. `*FOUNDATIONS*` — infra, projections, cleanup, deletions

Sections are stable scaffolding, not a checklist -- a quiet week drops a section
entirely rather than padding it.

## House style

The voice is the product. These rules reproduce it; the golden example shows it.

**Slack mrkdwn, raw.** Output the literal characters the user will paste:
- `_italic_`, `*bold*` (single asterisks -- NOT `**bold**`), `` `code` ``
- Links as `[label](url)`. (Vieko's Slack composer auto-converts this; don't use `<url|label>` unless asked.)
- Bullets are `• ` (literal bullet char), not `-` or `*`.
- WHAT'S NEXT items are numbered with `:1-dark:` `:2-dark:` `:3-dark:` emoji, not `1.`
- Title line: `:lead-agent: *LEAD AGENT this week*`

**Punctuation:** Use `--` for the em-dash role. Never use a literal em-dash (—). Better
still, reach for a colon, semicolon, or comma when it fits the sentence -- the dash is
the fallback, not the default. Avoid en-dashes too: write "0-100", "14 to 9".

**"Stage", never "Chapter."** The epic's internal docs say "Chapter"; the report says
"Stage." Translate on the way out (`Chapter 2.b` → `Stage 2`).

**Value over mechanism -- this is the whole game.** Each bullet leads with what the
change *brings to the table*, then just enough mechanism to be credible. The reader
should learn what's now possible, not what the diff did.
- Yes: *"We catch customers about to churn now:"* then one sentence on the gap that closed.
- No: *"Expanded CHURN_PHRASES regex to match verb-form cancellation."*

**Collapse PRs into outcomes.** Eight hardening PRs become one bullet ("Sends are now
safe and correct:") with the sub-fixes folded into a single sentence. The reader counts
outcomes, not commits. It's fine to mention the PR count as texture ("eight hardening
PRs this week") in a section tagline.

**Bullet structure:** `• *Bold lead-in phrase:* the explanation.` Trailing Linear links
at the end of the bullet: `([GTMENG-1402](url))`. Multiple IDs comma-separated inside
one paren.

**Intro line:** one `_italic_` paragraph, 2-3 sentences, naming the week's headline(s)
-- the thing a skimmer should walk away with. Pull it from the most consequential items
(a flag flip, a measurement window closing, a model swap, a big UX week).

**Section taglines:** a short `_italic_` line under a section header is good when the
section has a theme ("_Biggest UX week since launch -- the queue is now a real work
surface._"). Optional; use when it earns its place.

**WHAT'S NEXT:** exactly three items, the genuine next priorities -- pulled from
bonfire's "In flight" / "Next Steps" / blocked items. Lead with the outcome and name
the gating dependency honestly (e.g. "gated on MOPS restoring field permissions").

## Output

Write the finished report to `<repo>/.bonfire/drafts/lead-agent-this-week.md` so it's a
reviewable artifact in the gitignored drafts area, then offer the clipboard one-liner:

```bash
pbcopy < <repo>/.bonfire/drafts/lead-agent-this-week.md
```

Present the raw mrkdwn in the reply too, so the user can eyeball it before pasting.

## After a real report ships

When the user tells you what they actually posted (it may differ from your draft -- they
edit for voice), **update `references/golden-example.md` with the shipped version.** The
golden example should always be the most recent real post, so the voice anchor never
drifts from what Vieko actually publishes. This skill lives in the dotfiles repo, so
that's a normal `cd ~/.dotfiles && git add` + commit.
