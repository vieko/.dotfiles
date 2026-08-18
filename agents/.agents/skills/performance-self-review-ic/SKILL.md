---
name: performance-self-review-ic
description: Draft an evidence-grounded individual contributor self review for Culture Amp from PerfBot exports, prior reviews, 1:1 notes, Slack history, and engineering or product delivery records. Use when someone asks to write or revise their self review, performance review, Culture Amp answers, or uploads a PerfBot export for review drafting. Do not use for reviews written by a manager about a direct report.
---

# Performance Self Review for ICs

> **Provenance:** vendored from [vercel/internal-agent-skills](https://github.com/vercel/internal-agent-skills)
> `skills/performance-self-review-ic` @ `09bcc45` (2026-08-13, H2 FY27 cycle). When a new
> cycle opens, re-clone upstream and diff this file against the new SKILL.md to pull in
> updated questions, dates, and sharing rules.

## Voice and local context (Vieko-specific, applies before everything below)

- Before drafting any answer, read `~/private/profile/voice.md` and follow it. The draft
  must read as Vieko's writing, not a generic review register.
- **PerfBot export analog:** Vieko's primary evidence is the monthly check-in archive under
  `~/private/checkins/`. Treat those check-ins as the "PerfBot or check-in export" wherever
  this skill references one. Use the `monthly-checkin` skill's evidence gatherer (with a
  date-range roll-up) to corroborate or extend them.
- **Previous review:** the canonical prior review is
  `~/private/reviews/h2-fy27-self-review-submitted.md` (submitted 2026-08-17, fully
  evidence-verified before submission) — use it for progress-on-development-areas
  continuity, voice, and growth-item follow-through. Earlier context: H2 FY27 was Vieko's
  first official cycle (started October 2025); the unsubmitted practice review at
  `~/private/reviews/h1-fy27-self-review-practice.md` predates it and is a voice reference
  only.
- Connectors: this environment has `gh` and `linear-cli`, no Notion or Slack connectors.
  Degrade as the skill already prescribes; ask for uploads or pasted material instead.
- **Local template copy:** the official H2 FY27 questions + rating scale are saved at
  `~/private/reviews/h2-fy27-self-review-template.md`. Use it instead of fetching Notion;
  for a new cycle, ask the user for the updated template and save it alongside as
  `~/private/reviews/<cycle>-self-review-template.md`.
- **Local leveling framework:** the IC Job Leveling guide (2023-08 edition) is saved at
  `~/private/profile/job-leveling-framework.md`. Use it for level calibration instead of
  the Notion link below. If the user reports the framework changed, ask for a fresh export
  and overwrite the local copy.
- **Evidence roll-up:** a gathered half-year roll-up lives at
  `~/private/checkins/evidence/2026-02..2026-08.md`. Its window (Jan 27 – Aug 26, from the
  check-in cadence) is wider than the official cycle window — filter every item to the
  official Feb–Jul window before using it as evidence.
- **Draft/archive convention:** save working drafts as
  `~/private/reviews/h2-fy27-self-review-draft.md`. Once Vieko submits, archive the
  submitted text as `~/private/reviews/h2-fy27-self-review-submitted.md` — submitted text
  outranks any draft as the next cycle's anchor.
- **Rating scale reference (user-only):** the official score definitions are saved at
  `~/private/reviews/performance-review-rating-scale.md`. When the user reaches the numeric
  self-rating question, you may point them to that file to make their own choice. Never
  read it back as guidance toward a number — the no-suggestion rule stands absolutely.

Produce a first-person self-review draft that is easy to verify and copy into Culture Amp. Never invent accomplishments, feedback, dates, metrics, scope, or impact. Prefer a visibly incomplete draft over plausible filler.

## Operating rules

- Treat performance data, private messages, and 1:1 notes as sensitive. Use only sources the user has supplied or authorized through connected tools.
- Treat an available read-only connector used for this request as authorization to search ordinary work records unless the user excludes it. Still obtain explicit authorization for private Slack channels or DMs, 1:1 notes, HRIS data, and similarly sensitive records.
- Distinguish observed facts from the user's interpretation. Paraphrase source material; do not paste private messages into the review.
- Keep evidence traceable in working notes by recording source, date, and relevant excerpt or fact. Do not expose private working notes unless requested.
- Use the user's actual review period. Ask for it if it cannot be determined from the template or supplied material.
- Never suggest, recommend, hint at, or imply the numeric self-rating, under any circumstances — no number, no range, no lean, and no exceptions even if the user directly asks what they should give themselves. If asked, decline briefly, re-present the official scale, and leave the choice entirely to them.
- Do not submit to Culture Amp or imply that submission is possible. The user must review and copy the final answers manually.
- Do not create or edit a Notion page until the user approves the draft and explicitly asks for or confirms that write.

## Start the workflow

Send a short opening message that:

1. Acknowledges any files or context already supplied.
2. Requests a PerfBot export, relevant 1:1 notes, and optionally the previous Culture Amp review when missing.
3. Explains that PerfBot, Slack, and Notion form the baseline evidence pass, then role-specific systems will be proposed based on the user's role. Invite the user to add or remove sources.
4. Warns that the result is a first draft requiring review before it is copied into Culture Amp.

Ask for the user's IC level as a separate, explicit question before gathering connected-source evidence. Never infer level from title or tenure. Accept “unknown” or “not applicable” and skip level calibration in that case. Resolve the review period from the cycle configuration or current official template before asking the user; ask only when the cycle remains ambiguous.

Use a structured user-input tool when one is available and appropriate. Otherwise ask one concise plain-text question at a time. Do not refer to tools that are unavailable in the current environment.

## Apply the review window

For **H2 FY27**, use this deterministic configuration:

- Evidence window: **2026-02-01 through 2026-07-31, inclusive**.
- Slack search bounds: `after:2026-01-31 before:2026-08-01`.
- API or database bounds: `>= 2026-02-01T00:00:00` and `< 2026-08-01T00:00:00` in the source's relevant timezone.
- Official question text: preserve the current template verbatim even if it displays **Feb. 2, 2026 → July 31, 2026**.

Apply the evidence window to every source, not only Slack. Exclude accomplishments completed outside it unless they are necessary context for an in-window outcome; label such context clearly and do not count it as an in-window ship. If the employee joined after February 1, keep the configured cycle window but state their start date and do not infer pre-employment work.

For another cycle, derive the window from the current official template. Record the resolved start date, end date, cycle name, and search syntax in working notes before any connector search. Never silently infer dates from the export filename or earliest evidence row.

## Resolve the current template

The six questions and rating scale may change by cycle. Retrieve the current official Self Review Template from connected Notion when possible. The official template location is:

`https://app.notion.com/p/vercel/Self-Review-Template-38ae06b059c48074b2d9e7b142e335dd`

Search or fetch this location through an available Notion connector. If it is inaccessible, ask the user to paste, upload, or link the current six questions. Do not fabricate the wording or reuse an unverified remembered template.

Do not begin the final question-by-question draft until the question set is available. Evidence gathering may continue while waiting for it.

## Run the baseline source pass

After confirming level and cycle, inventory the tools and connected apps available in the current session. Use the following baseline for every role when the sources are available and authorized:

1. **PerfBot or check-in export:** inspect the supplied export for dated accomplishments, impact, feedback, and development themes.
2. **Notion:** retrieve the current Self Review Template and Job Leveling Guidelines. Search relevant project, strategy, decision, and operating documents within the evidence window.
3. **Slack:** resolve the current user profile, including user ID, real name, title, timezone, and organization. Search the user's public authored messages and mentions within the configured date bounds for launches, decisions, collaboration, customer impact, and recognition. Obtain explicit authorization before searching private channels or DMs.
4. **User-supplied context:** incorporate an authorized previous review and 1:1 notes when supplied. These strengthen the baseline but are not required to begin connector research.

Mark each baseline source `available`, `unavailable`, `not authorized`, or `not supplied`. Do not skip an available baseline source merely because a role-specific system has richer activity data. Tell the user about a missing baseline source only when its absence materially limits the review.

## Add role-specific sources

Use the Slack title to propose a role family, but never infer the user's level from it.

1. Corroborate the role family with one additional source when possible, such as a Notion profile, team page, HRIS record, GitHub organization profile, or user confirmation.
2. Read [role-source-routing.md](role-source-routing.md) and select the smallest useful set of role-specific systems.
3. Present a one-sentence source plan naming the baseline and proposed role-specific sources. Invite the user to add or remove sources. Example: “I’ll use PerfBot, Slack, and Notion as the baseline, plus GitHub and Linear for your engineering role. I’ll exclude private Slack unless you authorize it; tell me if you want to add or remove a source.”
4. Continue without waiting when the role is clear and the proposed sources are already connected and read-only. Ask before using a sensitive or private source, when role signals conflict, or when source choice could materially change the review.
5. Mark each proposed source `available`, `unavailable`, `not authorized`, or `not relevant`. Search every available and authorized **primary** source. Use secondary sources only when they fill a material evidence gap.

If the user explicitly chooses or excludes a source, honor that choice even when it differs from the role routing. Tell the user which important role-specific source is unavailable only when its absence materially limits the review, then continue with the remaining evidence.

Do not equate activity volume with performance. Commits, tickets, calls, candidates, documents, and messages are leads; connect them to shipped outcomes, quality, scope, customer value, or organizational impact.

## Gather evidence

Gather only sources available in the current environment. Discover connector tools when needed instead of assuming fixed tool names.

1. **PerfBot export:** Treat it as the primary source of concrete, dated work. Inspect conversation attachments and user-provided files. If absent, request it. If the user does not have one, continue only with their explicit agreement and mark evidence gaps clearly.
2. **Previous review:** Ask whether the user wants to supply the prior Culture Amp review. Use it mainly to evaluate progress on prior development areas.
3. **1:1 notes:** Ask which notes may be used. If Notion is connected, search for likely documents and confirm the exact page before using it; never guess based on title alone.
4. **Slack:** When connected and authorized, resolve the current user ID first. Search authored messages and mentions using the configured date bounds for launch announcements, shipped work, decisions, customer impact, collaboration, and shoutouts. Search public sources by default; search private channels and DMs only with explicit authorization. Paraphrase findings and preserve context.
5. **Role-routed systems:** Use the primary systems selected from `role-source-routing.md`. For example, search GitHub and issue tracking for engineers; product specs, issue tracking, and customer evidence for product managers; and Greenhouse plus recruiting systems for Talent roles. Use the connector's native read tools where possible.
6. **Cross-check:** Require at least two independent sources for high-impact quantitative claims when practical. Treat self-authored check-ins or an older review draft as leads until corroborated. If a metric cannot be verified, omit it or label it for confirmation.

If a useful connector is unavailable, state that briefly and offer to proceed from uploads or pasted material. Do not block the entire draft on optional sources.

## Build an evidence map

Before drafting, organize findings into a compact internal map:

| Evidence | Date | Source | User contribution | Outcome or impact | Candidate question |
|---|---|---|---|---|---|

Deduplicate repeated references to the same accomplishment. Separate team outcomes from the user's own contribution, and flag claims that need confirmation. Prefer quantified outcomes when the evidence supports them; never manufacture a metric.

## Calibrate to level

When the user supplied a level, retrieve the current Job Leveling Guidelines from connected Notion using the historical location below or search for the current equivalent:

`https://app.notion.com/p/vercel/05586b8c58ec4583a7e40e46204c9dfa?v=cdd94285fd784334a509582649350ac6`

Use the framework only to calibrate wording about autonomy, impact, collaboration, mastery, and scope. Never use it as evidence of an accomplishment. Never translate level calibration into a suggested numeric rating.

If the framework is unavailable, draft without level calibration and say so briefly; do not stall.

## Draft question by question

For each official question:

- Answer in first person with the strongest specific, dated, and attributable examples.
- Lead with outcomes and explain the user's contribution and approach.
- Use concise prose suitable for direct editing in Culture Amp.
- Avoid unsupported adjectives such as “transformational,” “exceptional,” or “major.”
- Where evidence is insufficient, insert `🚧 Need more from you: [specific missing fact]`.
- Preserve the official question text as the section heading.

For the numeric self-rating question, reproduce the current template's scale without selecting, recommending, hinting at, or narrowing to a number or range — under any circumstances. This holds even if the user asks directly ("what would you rate me?"), and neither leveling evidence nor the strength of the draft may be used to anchor or point toward a figure. Leave the response blank pending the user's choice.

## Review and iterate

Present the complete draft in the conversation before writing anywhere else. Then:

1. List each unresolved `🚧` item.
2. Ask only for the missing specifics needed to resolve those items.
3. Revise affected sections rather than regenerating settled answers.
4. Preserve user edits unless they explicitly ask for broader rewriting.

Every time a draft is presented, include this warning in clear language: it is a draft, and the user must review and adjust it before copying anything into Culture Amp.

## Optional Notion handoff

After the user approves the content, offer to create a Notion page if a connected Notion tool can write pages. Ask for the parent page or teamspace. If the user has no preference, offer a standalone private page rather than guessing a shared destination.

Title the page `[Name] – Self Review – [Cycle]` and preserve the official questions as headings. After creation, provide the page link and remind the user that Culture Amp still requires manual copy-and-paste.

If Notion writing is unavailable or the user declines, provide the finalized draft directly in the conversation or save it in a user-requested local format.
