# Luna report selection rules, version 2

The deterministic audit exports evidence only when `--prompts N` is present.
It preserves user-turn totals and samples the first N full-file user prompts,
including inherited fork context. Each prompt has a 300-character limit.
The classifier receives only the opener for `intent`. The auditing agent reads
session evidence to judge the work trajectory; the classifier does not label it.

## Received reports

Select only `custom_message` entries of custom type `pi-post` whose content
starts `Message from pi session`. Read the full body before applying the
2,000-character cutoff. Use `details.message.body` and `from.name` when present;
otherwise extract the sender and body from the displayed message.

Reject messages that start with coordination or dispatch language, including
`Summoner review`, `Scope change`, `Ack`/`Acknowledged`, `Approved`, `Relaying`,
`Please`, `Go`, `Proceed`, `Can you`, `Could you`, and `Report back when`.
Reject a body with a line that starts `New task`, `Next task`, or an imperative
`Report back when/with`. Reject progress or relayed-review language in the
opening line: `in progress`, `still working`, `checkpoint`, `progress update`,
or `review, relayed`. These exclusions also apply to construct senders.

Keep a body whose opening line states `Complete`/`Completed`, `Done`, `Finished`,
`Blocked`, `Giving up`, `Final report`, `Hand-back`, `Review fixes pushed/landed`,
or `Follow-up committed`. The marker can follow an issue ID or stage name.
Also accept an opening `REPORT:` or `lane report` title. Restrict status matching
to the opening line so later dispatch instructions do not become report evidence.
For a sender named `fam-*` or `golem-*`, also accept a result body that identifies
verification, deviations, a commit, or a push, with a completed/failed result.
A construct name alone does not make an acknowledgement a report.

This conservative rule can miss reports with unusual wording. A retained
message can also contain coordination after a completed result. Report the
selection count, and manually read representative retained and rejected bodies.
Do not use the retained count as a complete inventory of Familiar finishes.
The cutoff can hide verification or deviations. A false boolean label does
not prove that the full report omits the evidence.
