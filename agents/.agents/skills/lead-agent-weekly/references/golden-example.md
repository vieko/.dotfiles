# Golden example — LEAD AGENT project update

The most recent report Vieko actually posted to Slack. This is the voice/format anchor:
match its rhythm, bullet structure, value-first framing, and Slack mrkdwn before writing
a new update. Update this file with each shipped report so it never drifts from reality.

Shipped: 2026-07-17 (covering the previous two weeks).

---

:update: :lead-agent: *PROJECT UPDATE*

*What shipped in the last two weeks*
* Separated Startup leads from the enterprise Contact Sales scorer so Startup now has its own classification, response contract, and SFDC routing — while true enterprise opportunities still hand off cleanly to Lead Agent
* Made the VDR queue aware of live Salesforce state, with the working-set sync refreshing every 5 minutes so leads already worked in SFDC can automatically fall off the queue (filter is ready behind a flag)
* Fixed missing leads in regional and Mine views by keeping leads whose region could not be resolved visible to VDRs
* Made contact names editable in the dashboard so VDR corrections flow through to both the email preview and the message sent through Outreach
* Unified email preview and Outreach payload composition behind a flag, including the correct greeting, VDR calendar CTA, signature, and Startup-specific CTA suppression
* Corrected WAF product guidance so Pro-tier custom-rule inquiries no longer receive Enterprise-only framing

*What's next*
* Battle-test the Salesforce-backed queue with VDRs before enabling the filter — the first flip will remove roughly 94% of stale or already-worked leads from the visible backlog
* Measure the new Startup pipeline in production, then remove the remaining legacy Startup branches from the Contact Sales scorer
* Finish rolling out dashboard-owned email composition so the preview and delivered Outreach email are identical by construction
* Finish implementing Freaky Friday findings :muscle::skin-tone-3:
