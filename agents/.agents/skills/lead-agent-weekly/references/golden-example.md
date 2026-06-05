# Golden example — LEAD AGENT this week

The most recent report Vieko actually posted to Slack. This is the voice/format anchor:
match its rhythm, bullet structure, value-first framing, and Slack mrkdwn before writing
a new week. Update this file with each shipped report so it never drifts from reality.

Shipped: 2026-06-05 (covering the May 29 – Jun 5 window).

---

:lead-agent: *LEAD AGENT this week*
_Stage 2 measurement window closed clean. Claude Opus-4.8 is ramping behind a flag after two prod-faithful evals proved it cuts expensive misses nearly in half. The VDR dashboard had its biggest UX week yet._

*LEAD AGENT*
• *We catch customers about to churn now:* the cancel/retention gate only matched "cancelling" and missed the most common phrasing -- an existing customer saying they'll "cancel by tomorrow." Now those reach a human instead of getting auto-replied. ([GTMENG-1402](https://linear.app/vercel/issue/GTMENG-1402))
• *Opus-4.8 model swap, ramping behind a flag:* two prod-faithful evals cut expensive errors 14 to 9 and recovered the PwC/Eightcap deals the old model was losing, with no loss in false-positive discipline. +$209/mo worst-case, erasable via prompt caching. Flag-off is byte-identical; canary watcher live. ([GTMENG-1279](https://linear.app/vercel/issue/GTMENG-1279))
• *Stage 3 reasoner shrink retired:* we tried slimming the scorer to a narrow reasoner; the eval showed it hurt accuracy on every model, so we killed it and moved the maintainability win to a prompt refactor instead.
• *LATAM leads stop landing in the wrong queue:* region was derived contact-first, so LATAM accounts silently bucketed as AMER and hit Nicole's queue by mistake. Now account-first, with LATAM first-class. ([GTMENG-1381](https://linear.app/vercel/issue/GTMENG-1381))
• *Two reliability fixes:* VDR copy now matches the dashboard's region ([GTMENG-1356](https://linear.app/vercel/issue/GTMENG-1356)), and the MQL webhook no longer 5xx's on transient rate-limit errors ([GTMENG-1354](https://linear.app/vercel/issue/GTMENG-1354)).

*VDR DASHBOARD*
_Biggest UX week since launch -- the queue is now a real work surface._
• *Message-first detail view:* Decision + Research tabs, with the original inbound message and AE/account context right next to the email preview. Reviewers stop losing the thread.
• *Open in Salesforce deep-link:* one click from any submission to the SFDC record. No more manual lookup.
• *Region-scoped work queue:* a prioritized burndown list, filtered by region, so each VDR owns and works their own slice. ([GTMENG-1345](https://linear.app/vercel/issue/GTMENG-1345), [GTMENG-1382](https://linear.app/vercel/issue/GTMENG-1382))
• *Live Salesforce presence + server-side access control:* the SFDC button reads live state, and dashboard access is now enforced on the server, not just hidden in the UI. ([GTMENG-1117](https://linear.app/vercel/issue/GTMENG-1117))

*OUTREACH DELIVERY*
_Getting close -- eight hardening PRs this week on the path to un-pin._
• *Sends are now safe and correct:* delivery is locked to the VDR's own inbox, sender profile reads live (no more stale session), and prospect-creation races recover instead of erroring. ([GTMENG-1136](https://linear.app/vercel/issue/GTMENG-1136))
• *Honest failures:* the connect flow surfaces real Salesforce auth errors instead of silently swallowing them. ([GTMENG-1355](https://linear.app/vercel/issue/GTMENG-1355))
• *Rollout tooling:* CLIs to list connected VDRs and verify Outreach-to-SFDC sync before we flip it on, plus a webhook guard against replayed events. ([GTMENG-1114](https://linear.app/vercel/issue/GTMENG-1114))

*FOUNDATIONS*
• *Queue reads off a warm projection:* new `vdr_working_set` table and sync, so the queue no longer hits Snowflake cold on every load. ([GTMENG-1383](https://linear.app/vercel/issue/GTMENG-1383), [GTMENG-1385](https://linear.app/vercel/issue/GTMENG-1385))
• Incident degradation banner removed.

*WHAT'S NEXT*
:1-dark: *Outreach delivery un-pin:* gated on MOPS restoring integration-user field permissions (the Mailing-to-Task sync is currently blocked). Once that lands, the full send-to-SFDC flow can be verified and delivery goes live for VDRs.
:2-dark: *Opus-4.8 ramp:* canary watcher is live. Clean week, we widen the ramp; noisy, we refine gates first. ([GTMENG-1279](https://linear.app/vercel/issue/GTMENG-1279))
:3-dark: *Sequence enrollment:* field mapping is cleared, so after un-pin VDRs can enroll straight from the dashboard instead of jumping into Outreach. ([GTMENG-1410](https://linear.app/vercel/issue/GTMENG-1410))
