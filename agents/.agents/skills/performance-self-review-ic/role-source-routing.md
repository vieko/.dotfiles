# Role-aware evidence routing

Use this routing table after resolving the employee's title and role family. Always run the baseline source pass first, then propose the smallest useful set of role-specific sources. Invite the user to add or remove sources. Search every available and authorized primary source; use secondary sources only when they fill a material gap.

## Baseline sources

| Source | Default treatment | Evidence to seek |
|---|---|---|
| PerfBot or check-in export | Request or inspect when supplied | Dated ships, self-described impact, development themes |
| Slack | Search public authored messages and mentions when connected; ask before private channels or DMs | Launches, decisions, collaboration, customer feedback, recognition, blockers |
| Notion | Search when connected | Official template and leveling framework; strategies, PRDs, project records, operating documents, meeting decisions |
| Previous review and 1:1 notes | Use only when supplied or specifically authorized | Prior development areas, manager feedback, goals |

## Role routing

| Role family or title signals | Primary sources | Secondary sources | Strong evidence patterns |
|---|---|---|---|
| Software, infrastructure, data, security, engineering | GitHub; Linear/Jira; incident or observability systems | Notion; deployment records; customer/support signals | Shipped systems, reliability or latency changes, incidents resolved, technical direction, review quality, adoption |
| Product management, technical program management | Linear/Jira; Notion PRDs/roadmaps; launch records | GitHub; analytics; customer research/support | Outcomes shipped, prioritization decisions, adoption, customer value, cross-functional execution, portfolio tradeoffs |
| Design, research, content design | Figma or design system; Notion research; Linear/Jira | Slack; analytics; usability findings | Shipped experiences, research decisions, accessibility, design-system leverage, measured usability |
| Recruiting, talent, sourcing | Greenhouse ATS; recruiting analytics; approved sourcing systems | Slack; Notion; interview tooling | Hires and funnel movement, quality or speed improvements, process design, hiring-manager impact; avoid candidate PII in the draft |
| People, HR, L&D, People Technology | PerfBot/HRIS; Notion; Slack | Linear; GitHub; learning or survey systems | Employee or manager experience, adoption, time saved, risk reduction, scalable programs, internal products |
| Sales, account management, customer success | CRM; call intelligence; account plans | Slack; Notion; support systems | Revenue or retention influence, expansion, customer outcomes, forecast quality, reusable plays |
| Marketing, growth, communications | Analytics; campaign or CMS systems; project tracking | Slack; Notion; CRM | Pipeline or adoption contribution, audience reach, conversion, launches, reusable programs |
| Finance, legal, operations, procurement | ERP/finance or contract systems; project tracking; policy repositories | Slack; Notion; ticketing | Risk or cost reduction, cycle-time improvement, controls, decision quality, operational scale |
| Support, success engineering, solutions | Support platform; CRM; GitHub/Linear when technical | Slack; Notion; call intelligence | Resolution quality, customer unblock, recurrence prevention, product feedback, escalation leadership |

## Connector rules

- Prefer native connectors over web search or copied summaries.
- Discover tools by capability; never assume a fixed MCP tool name.
- Treat PerfBot, Slack, and Notion as the standard baseline. A role-specific system supplements rather than replaces them.
- State the proposed source plan in one sentence and let the user add or remove sources. Do not turn source selection into a blocking questionnaire when the defaults are clear and authorized.
- Treat available read-only connectors as authorized for ordinary work evidence in this request unless the user excludes them. Ask explicitly before accessing private Slack or DMs, 1:1 notes, HRIS records, or similarly sensitive material.
- If Slack is connected, resolve the current user's profile before searches containing a user ID.
- For private Slack channels or DMs, obtain user authorization before searching.
- For GitHub, distinguish authored code, reviews, design leadership, and team outcomes. Do not use commit count as impact.
- For Greenhouse, use approved aggregate recruiting evidence and exclude candidate names, interview feedback, or other candidate PII from the review draft.
- For CRM, finance, HRIS, and analytics data, preserve metric definitions and date windows. Do not claim attribution from correlation alone.
- If title signals span multiple families, search the union of their primary sources but keep the source plan small and relevant.
