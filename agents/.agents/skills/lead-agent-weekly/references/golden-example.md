# Golden example — LEAD AGENT project update

The most recent report Vieko actually posted to Slack. This is the voice/format anchor:
match its rhythm, bullet structure, value-first framing, and Slack mrkdwn before writing
a new update. Update this file with each shipped report so it never drifts from reality.

Shipped: 2026-08-07 (covering the previous three weeks). Transcribed from the posted
message; the `SPAM SURFACE` link target is elided. Things Vieko changed from the agent
draft on the way out, worth knowing: an italic `*TL;DR*` line was kept because the window
was three weeks; two trailing "so that..." clauses and a row-count stat were cut; UI
labels became inline code (`IN SEQUENCE`, `Unenroll`) or a link (`SPAM SURFACE`); a
collaborator got an @-mention on the bullet he owned part of; and two dry asides landed
("for the next time someone is bored and feeling evil", "(telemetry, baby)"). One aside
per report is the ceiling.

---

:update: :lead-agent: *PROJECT UPDATE*

_TL;DR — Startup is fully separated from the CS scorer, the VDR dashboard is becoming a complete work surface, and we closed the biggest gaps exposed by July's spam campaign. We also traced the Exa spend run-up and shipped the first round of cost controls._

*What shipped in the last three weeks*
* Closed out the Startup migration for good — startup traffic now runs through its own pipeline, the post-cutover soak had zero failures, and enterprise SQ volume re-baselined from ~130 to ~40/wk as forecast
* Made the VDR queue easier to work: SQ and MIR now share one _TO WORK_ view, every row shows owner and segment, search finds leads across the full history (including by SFDC ID)
* Added visibility and control for live Outreach cadences: an `IN SEQUENCE` badge now shows when a lead is getting worked, and a new role-gated `Unenroll` action is ready behind a flag
* Closed the gaps exposed by July's Contact Sales spam attack: malicious patterns now short-circuit before paid enrichment, spam-patterned repeats no longer escalate to VDRs, and the new [SPAM SURFACE](<url>) tracks bot rates and attack indicators for the next time someone is bored and feeling evil
* Made the scorer fairer and more current: legitimate repeat submitters hard-gated to NSR now get a drafted self-serve redirect instead of silence, plan-gated rules work again through CRM fallback, and custom-environment guidance reflects the latest Pro offering @Joseph Robinson
* Traced the Exa spend run-up ($1.8K to $13.4K to tracking ~$24K this cycle) and shipped the first controls: free eligibility checks before paid research, dead sources removed, fail-closed tool config, a dark-launched research cache, and per-call cost attribution (telemetry, baby) — first post-fix data shows ~$335/day versus the ~$800/day the invoice implies

*WHAT'S NEXT*
* Publish the first full week of per-operation Exa cost data (~Aug 14) and use it to decide when to turn on cache reads and how to size the 12-month spend commitment
* Turn on the `Unenroll` action for VDRs and restore the production Outreach webhook mirror so delivery, reply, and bounce signals flow back to the dashboard in real time
* Decide how to handle startup-credit requests still arriving through the enterprise Contact Sales form (~4/wk) — the last startup-flavored behavior left in the CS scorer!
