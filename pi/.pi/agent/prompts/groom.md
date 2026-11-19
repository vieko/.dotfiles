---
description: Groom my Linear views and cycle; propose, then apply on approval
argument-hint: "[close] (add 'close' in the last days of a cycle)"
---
Groom my Linear queues. Propose first; change nothing in Linear until I pick
an option. `$1` = `close` also closes out the active cycle and plans the next.

**Read** (one `codemode` script, Linear MCP; gotchas in the `linear-cli`
skill, which also lists the seven view ids and what each one is for):

1. Every view with `mcp__linear__list_issues({ customView: <id>, fields:
   ["id", "title", "status", "priority", "project", "cycleId", "parentId",
   "updatedAt"] })`. Page until `hasNextPage` is false.
2. The active and next GTMENG cycles: `mcp__linear__list_cycles`.
3. For Inbox items, `list_comments`, to see who asked and whether a
   Slack-synced thread exists.
4. `~/.scripts/linear-cycle-sync.sh` (dry run): started or finished work
   that is missing from the active cycle.

**Targets:** Inbox 0, Unsorted 0, Next about 10, Active only work that is
really moving. Backlog is groomed, not emptied.

**Propose**, as `~/scratch/linear-groom-<YYYY-MM-DD>-review.md` and in
the reply, one line per issue with the action and the reason:

- **Inbox**: promote (state, project, priority), assign, or cancel. Issues I
  filed into other teams stay in their triage; say so once.
- **Unsorted**: a priority and a project for each item, or cancel it.
- **Active**: for an issue started more than 7 days ago with no open PR and
  no recent commit, move it back to Todo or mark it blocked. A merged PR with
  the issue still open means close it.
- **Next**: under about 10, propose additions from Backlog (High first);
  over about 10, propose what goes back. Additions to a cycle are my call.
- **Sagas**: a parent whose sub-issues are all done gets closed.
- **Vulns**: only items not in Verify Fix need action from me.
- **Backlog**: up to 10 items untouched for more than 60 days, to cancel or
  keep.
- With `close`: each unfinished issue in the active cycle goes to the next
  cycle or back to Backlog (no cycle).
- Drafts for any reply to a person, as children of the Slack-synced root
  comment (see the skill). Replies post as me.

End with a lettered list: (a) apply all, (b) apply all except the items I
name, (c) apply nothing.

**Apply** only what I chose. Run `linear-cycle-sync.sh --apply`. Read every
view again to verify, and append an "Applied <date time>" section to the
review file with the final counts per view.
