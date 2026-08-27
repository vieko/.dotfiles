---
name: performance-peer-review
description: Drafts a peer review write-up for Culture Amp. Use when the user wants to write or draft a peer review of a colleague, or a first-pass answer to the Culture Amp peer review questions. Cycle dates and template paths live in the skill body.
disable-model-invocation: true
compatibility: Any assistant with access to a workplace chat search tool (e.g. Slack, Teams) and/or a docs/wiki search tool (e.g. Notion, Confluence, Google Docs) is sufficient. A page-creation tool for the docs/wiki system is optional — the skill works without it, just skip Step 5.
---

# Peer Review Drafter

> **Provenance:** vendored from [vercel/internal-agent-skills](https://github.com/vercel/internal-agent-skills)
> `skills/performance-peer-review` @ `09bcc45` (2026-08-13, Feb 1 – Jul 31 2026 cycle).
> When a new cycle opens, re-clone upstream and diff this file against the new SKILL.md.

## Voice and local context (Vieko-specific)

- Before drafting, read `~/private/profile/voice.md` and write in Vieko's voice. Peer
  reviews are semi-formal, but they still shouldn't read like generic HR prose.
- No Slack/Notion connectors in this environment: skip the search steps and go straight to
  the interview-the-user path. Vieko's monthly check-ins (`~/private/checkins/`) often name
  collaborators and shared seams — use them as leads for the collaboration-only filter,
  then confirm specifics with Vieko.
- **Local template copy:** the official H2 FY27 peer questions + sharing rules are saved
  at `~/private/reviews/h2-fy27-peer-review-template.md`. Trust it over the inline
  question text below if they ever disagree; for a new cycle, save the updated template
  alongside as `~/private/reviews/<cycle>-peer-review-template.md`.
- **Draft/archive convention:** save working drafts as
  `~/private/reviews/h2-fy27-peer-review-given-<name>-draft.md`. Once submitted, archive
  the final text as `~/private/reviews/h2-fy27-peer-review-given-<name>.md` (matching the
  H1 archive naming).

Produces a grounded first-draft peer review for Culture Amp — ready to read, edit, and paste in. The non-negotiable rule: never invent specifics you weren't given evidence for, and never include work the reviewee did independently — only include work the reviewer and reviewee did together. A partial draft with honest gaps is the right output. A polished-sounding draft built on guesses or solo work is not.

## Formatting rule: writer guidance goes in italics, never in brackets

Any notes or instructions you write for the reviewer (e.g., prompts to add their own words, reminders to personalize a section, flags about what's missing) must be formatted as italicized text on its own line below the relevant section. Never put writer guidance inside [brackets] inline with the draft text — those get accidentally copy-pasted into Culture Amp.

**Example of what NOT to do:**

Olivia was a strong partner on [add specific project here] and helped me [describe the outcome].

**Example of what TO do:**

Olivia was a strong thought partner throughout the review period.

*Add a specific project or moment here — what did you work on together and what was the outcome?*

This rule applies everywhere in the draft: question headers, section bodies, and the Direct Feedback section.

## Review period

Feb 1, 2026 → July 31, 2026. Only include evidence from this window. If something happened outside it, note that and set it aside.

## The three questions this draft must answer

1. What did you work on with this person during the review period (Feb. 1, 2026 → July 31, 2026) and what was their impact?
2. What do you want to see more of from this person?
3. Direct Feedback (optional — the reviewer decides how much to share here): Some people prefer to give feedback confidentially, others are ready to share it directly with their peer. This section is your chance to do the latter. You can copy and paste everything you wrote above, leave this section blank, or do anything in between. It's entirely up to you. Remember: any feedback provided in this section will be directly shared with your peer, and your name will be attached.

## Step 1: Establish who they're reviewing

Ask upfront (or confirm from what they said):

- Who are you reviewing? (name or @handle)
- Your relationship: How did you work together — same team, cross-functional, collaborator on a specific project?

If they haven't volunteered this, ask before searching anything.

## Step 2: Search for context — collaboration only

Use whatever search tools are available in your environment, but apply a strict filter: only keep evidence that shows the reviewer and reviewee working together. Discard anything that only shows what the reviewee did on their own, even if it's impressive.

**Signs of genuine collaboration to look for:**

- Both names appear in the same thread or message
- The reviewer is CC'd and actively engaged (not just a passive recipient)
- Shared documents, meetings, or projects that both contributed to
- One person explicitly helping, reviewing, unblocking, or partnering with the other

**Do not include:**

- Things the reviewee shipped independently, even if the reviewer was loosely aware
- Messages where the reviewer is CC'd but not actively involved
- Projects the reviewee owns where the reviewer had no direct role

### Workplace chat (Slack, Teams, or equivalent)

If a chat-search tool is available:

- Search for the reviewee's name filtered to the review period
- Look specifically for threads or DMs that include both the reviewer and the reviewee
- Look for shared channels they're both in
- Use what you find as raw material — paraphrase/summarize rather than quoting messages verbatim

### Docs/wiki (Notion, Confluence, Google Docs, or equivalent)

If a docs-search tool is available:

- Search for shared docs, meeting notes, project pages, or 1:1 notes that involve both people
- Look for project retrospectives or specs where both names appear

### If no search tools are available

Skip straight to asking the reviewer directly using the questions below — don't guess at collaboration history from memory or general knowledge.

### When you don't have enough

If searches return thin or ambiguous results — or if you're unsure whether something was truly collaborative — ask before drafting:

> "I found some things but want to make sure I'm capturing the right work. Can you help me with a few questions?
>
> - What are 1–2 projects you worked on together during the review period?
> - Is there a doc for any of those projects I should look at?
> - Are there specific channels where you collaborated most?
> - Any specific moments — a launch, a tough situation, a decision you made together — that stand out?"

Ask these questions before writing question 1. Do not draft from thin or ambiguous evidence — a 🚧 placeholder is better than a guess.

## Step 3: Draft each question

Work through all three questions. For each one:

- Only include work the reviewer participated in directly — not work the reviewee did solo
- Use specific, dated, concrete examples where you have them
- If you don't have enough to answer a question credibly, write the question header and then: 🚧 I don't have enough context here — can you share [what's missing]?

For the Direct Feedback section: draft a version that mirrors what was written in questions 1 & 2, then end the drafted text with 🚧 on its own line to signal that this section needs their personal review and editing before submitting. Below the 🚧, add on its own line in italics: *This section is entirely your call — you can use all of it, part of it, or leave it blank. Your name will be attached to anything in this section.* Do not pressure them to include anything.

Any other notes or prompts for the reviewer (e.g., "consider adding a specific example here") must appear as italicized text on a new line below the relevant section — never inline in [brackets].

## Step 4: Show the draft in chat first

Present the full draft in the conversation — not yet saved anywhere else — so it's easy to correct or fill gaps. Lead with this reminder every time:

> ⚠️ This is a first draft. Please read it carefully and edit it before entering anything into Culture Amp. Do not submit it as-is. If any section says 🚧, it means I didn't have enough context — fill those in with your own words.

Call out each 🚧 gap and ask for specifics. When they reply with more detail, update only the affected sections.

## Step 5: Offer to save a copy (optional)

If a page-creation tool for a docs/wiki system is available, once the draft is in good shape, offer to save it there so they have it outside the chat window. Title: `[Reviewer] → [Reviewee] – Peer Review – H2 FY27`. Ask which workspace, team, or parent location to use; if they don't care, create it as a private standalone page. If no such tool is available, skip this step — the in-chat draft is the deliverable.

## Step 6: Hand off

Close with just these three things:

- Link to the saved page (if one was created)
- Reminder that this is a draft to edit, not submit
- That Culture Amp can't be written to directly — they'll need to copy each answer into the matching field manually

Keep the handoff short. No lengthy caveats.
