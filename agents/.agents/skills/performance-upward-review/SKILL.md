---
name: performance-upward-review
description: Drafts a direct report's upward review for Culture Amp using workplace chat and docs context. Use when someone says "write my upward review," "help me review my manager," "draft feedback for my manager," or wants a first-pass answer to the Culture Amp upward review questions for the Feb 2 – July 31, 2026 cycle.
compatibility: Any assistant with access to a workplace chat search tool (e.g. Slack, Teams) and/or a docs/wiki search tool (e.g. Notion, Confluence, Google Docs) is sufficient. A page-creation tool for the docs/wiki system is optional — the skill works without it, just skip Step 5.
---

# Upward Review Drafter

> **Provenance:** vendored from [vercel/internal-agent-skills](https://github.com/vercel/internal-agent-skills)
> `skills/performance-upward-review` @ `09bcc45` (2026-08-13, Feb 2 – Jul 31 2026 cycle).
> When a new cycle opens, re-clone upstream and diff this file against the new SKILL.md —
> especially the sharing-rules table, which must never go stale.

## Voice and local context (Vieko-specific)

- Before drafting, read `~/private/profile/voice.md` and write in Vieko's voice.
- No Slack/Notion connectors in this environment: skip the search steps and use the
  interview-the-user path directly. H2 FY27 is Vieko's first official cycle; there is no
  received Culture Amp history. Reviews Vieko previously wrote for others may exist under
  `~/private/reviews/` — use them as register anchors only, never as evidence.
- **Local template copy:** the official H2 FY27 upward questions + per-question sharing
  rules are saved at `~/private/reviews/h2-fy27-upward-review-template.md`. Trust it over
  the inline question text below if they ever disagree; for a new cycle, save the updated
  template alongside as `~/private/reviews/<cycle>-upward-review-template.md`.
- **Manager Job Description:** saved locally at `~/private/profile/manager-job-description.md`
  (the doc the official template links in Notion). Use it the way the self-review skill uses
  the leveling framework: to calibrate wording about what a Vercel manager is expected to do
  (qualifications + five responsibility areas). Never cite it as evidence of what the manager
  actually did, and never use it to pick or hint at a Likert rating.
- **Draft/archive convention:** save working drafts as
  `~/private/reviews/h2-fy27-upward-review-given-<manager>-draft.md`. Once submitted,
  archive the final text as `~/private/reviews/h2-fy27-upward-review-given-<manager>.md`
  (matching the H1 archive naming).

Produces a grounded first-draft upward review for Culture Amp — ready to read, edit, and paste in. The non-negotiable rule: never invent specifics you weren't given evidence for. A partial draft with honest gaps is the right output. A polished-sounding draft built on guesses is not.

## Review period

Feb. 2, 2026 → July 31, 2026. Only include evidence from this window.

## Formatting rule: writer guidance goes in italics, never in brackets

Any notes or instructions you write for the employee (e.g., prompts to personalize a section, reminders to add their own words, flags about what's missing) must be formatted as italicized text on its own line below the relevant section. Never put writer guidance inside [brackets] inline with the draft text — those get accidentally copy-pasted into Culture Amp.

**Example of what NOT to do:**

Olivia has been supportive of my growth by [describe specific example here].

**Example of what TO do:**

Olivia has been a supportive manager throughout this period.

*Add a specific example here — a moment when she supported your growth or helped you navigate something challenging.*

This rule applies everywhere in the draft: question bodies, rating evidence notes, and the Direct Feedback section.

## Critical: what gets shared with the manager

Several questions are confidential (shared only with the manager's manager). Others are shared directly with the manager. Always label each section clearly in the draft so the employee knows what their manager will see.

| Question | Shared with manager? |
|---|---|
| 1. What went well? | ❌ NOT shared |
| 2. What could've gone better? | ❌ NOT shared |
| 3. What can your manager do to support you more? | ✅ WILL be shared |
| 4. My manager gives me constructive feedback I can act on. (rating) | ❌ NOT shared |
| 5. My manager clearly communicates expectations. (rating) | ❌ NOT shared |
| 6. My manager enables me to do my best work. (rating) | ✅ WILL be shared |
| 7. Direct Feedback | ✅ WILL be shared (name attached) |

Make these sharing rules visible in the draft — employees should never be surprised by what their manager sees.

## The seven questions this draft must answer

1. **What went well?**
   - Describe at least one concrete example of something your manager did well during Feb. 2 – July 31, 2026.
   - What was the impact on your work, your team, or your professional development?
   - *(NOT shared with manager)*
2. **What could've gone better?**
   - Describe at least one concrete example of something your manager could have done better during Feb. 2 – July 31, 2026.
   - What was the impact on your work, your team, or your professional development?
   - *(NOT shared with manager)*
3. **What can your manager do to support you more on a day-to-day basis?**
   - *(WILL be shared with manager)*
4. **My manager gives me constructive feedback I can act on.** Strongly Disagree / Disagree / Neutral / Agree / Strongly Agree
   - *(NOT shared with manager)*
5. **My manager clearly communicates expectations.** Strongly Disagree / Disagree / Neutral / Agree / Strongly Agree
   - *(NOT shared with manager)*
6. **My manager enables me to do my best work.** Strongly Disagree / Disagree / Neutral / Agree / Strongly Agree
   - *(WILL be shared with manager)*
7. **Direct Feedback (optional)** — Some people prefer to give feedback confidentially, others are ready to share it directly with their manager. You can copy and paste everything you wrote above, leave this section blank, or do anything in between. Remember: any feedback in this section will be shared directly with your manager, and your name will be attached.
   - *(WILL be shared with manager, name attached)*

## Step 1: Establish context before searching

Ask these questions upfront — don't search until you have them:

- Who is your manager? (name or @handle)
- Do you have 1:1 notes in a docs/wiki tool or elsewhere? If so, can you share the link or title?
- Are there specific chat channels where you and your manager interact most? (e.g., a team channel, a private channel, a shared project channel)
- Are there any specific moments — a tough situation, a piece of feedback, a decision — that stand out from this period?

These answers will focus the search and produce a much more accurate draft than a broad keyword search alone.

## Step 2: Search for evidence of manager behaviors

The upward review is about how the manager managed — not just what projects happened. Use whatever search tools are available in your environment, and look for evidence of:

- How the manager communicated expectations, gave feedback, or removed blockers
- Moments where the manager supported (or didn't support) the employee's growth or work
- Patterns across 1:1 notes, team channels, or direct messages

### Docs/wiki (Notion, Confluence, Google Docs, or equivalent)

If a docs-search tool is available:

- Search for the manager's name + "1:1" or the specific doc title the employee provided
- Look for meeting notes, feedback docs, or project pages where both names appear
- Read 1:1 notes carefully — they're the best source for manager behavior evidence

### Workplace chat (Slack, Teams, or equivalent)

If a chat-search tool is available:

- Search in channels the employee named, filtered to Feb 2 – July 31, 2026
- Look for the manager giving feedback, setting direction, recognizing work, or handling difficult situations
- Look at DMs between the employee and manager if accessible
- Use what you find as raw material — paraphrase/summarize, don't quote verbatim

### If no search tools are available

Skip straight to asking the employee directly using the follow-up questions below — don't guess at manager behavior from memory or general knowledge.

### If context is still thin after searching

Ask follow-up questions before drafting:

> "I didn't find enough to write confidently. A few more questions:
>
> - Can you think of a specific moment when your manager gave you feedback — positive or constructive?
> - Was there a situation where your manager stepped in to help, or a time when you wished they had?
> - How do you generally feel about how clearly they set expectations and enable your work?"

## Step 3: Draft each question

Work through all seven questions:

- For questions 1 and 2: use specific, dated, concrete examples ("in March when X happened, my manager did Y")
- For question 3: make it actionable and forward-looking — what would actually help?
- For the rating questions (4, 5, 6): never pick a rating for the employee. Always leave these as an explicit choice with the scale shown. Write a brief note on what evidence exists that might inform each rating, but let them decide. Any evidence notes should be in italics on a new line below the rating options — not in [brackets].
- For question 7 (Direct Feedback): draft a version that mirrors what was written in questions 1–3, then end with 🚧 on its own line. Below the 🚧, add on its own line in italics: *This section is entirely your call — you can use all of it, part of it, or leave it blank. Your name will be attached to anything in this section.*
- If you don't have enough to answer a question credibly: write 🚧 I don't have enough context here — can you share [what's missing]?
- Any other notes or prompts for the employee must appear as italicized text on a new line below the relevant section — never inline in [brackets].

## Step 4: Show the draft in chat first

Present the full draft in the conversation — not yet saved anywhere else. Lead with this reminder every time:

> ⚠️ This is a first draft. Please read it carefully and edit it before entering anything into Culture Amp. Do not submit it as-is.
>
> Pay special attention to the sharing labels on each question — some of your answers will be visible to your manager. If any section says 🚧, fill it in with your own words before submitting.

Call out each 🚧 gap and ask for specifics. When they reply with more detail, update only the affected sections.

## Step 5: Offer to save a copy (optional)

If a page-creation tool for a docs/wiki system is available, once the draft is in good shape, offer to save it there. Title: `[Employee] → [Manager] – Upward Review – H2 FY27`. Ask where to save it; if they don't care, create it as a private standalone page. If no such tool is available, skip this step — the in-chat draft is the deliverable.

## Step 6: Hand off

Close with:

- Link to the saved page (if one was created)
- Reminder that this is a draft to edit, not submit
- That Culture Amp can't be written to directly — they'll need to copy each answer into the matching field manually
- A note to double-check the sharing labels before submitting — especially question 7

Keep the handoff short.
