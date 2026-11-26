---
description: "Close out this session: loose ends, unreaped constructs, what carries forward"
argument-hint: "[anything you want weighed, e.g. 'we are done with 3910']"
---
Wrap this session. Answer "anything else for this session?" with evidence, not
memory. Read-only commands only; do not commit, push, merge, or clean anything
up until I pick an option. Extra context from me: `$@`.

**Open with the verdict** in one line: "Safe to close" or "Not yet: <the one
thing>". Then the sections below.

**Check, in this order:**

1. **Promised, not done.** Scan this conversation for things I asked for or
   you said you would do that have no result in the transcript: files to
   write, PRs to open or merge, Linear comments, messages to other sessions,
   follow-up checks. One line each, or "none".
2. **Decisions waiting on me.** Lettered options you offered that I never
   answered, questions still open.
3. **PRs and issues.** Every PR this session opened or touched: state
   (`gh pr view <n> --json state,mergeStateStatus,reviewDecision`), and for
   merged ones whether the linked Linear issue reached Done (the GitHub
   integration moves it a few seconds after the merge; check, do not race
   it). Write each as a link: `[#6259](url)`, `[GTMENG-4761](url)`.
4. **Working tree.** `git status --short` in the cwd and in any worktree this
   session created or touched (`git worktree list`). Uncommitted or unpushed
   work, branches ahead of origin, worktrees of merged branches.
5. **Constructs.** `~/.scripts/construct-term.sh list` (tmux and Rex),
   `anvil status --since 1d` (skip if absent), familiars this session
   dispatched (`list_sessions` for ones still live). For each: done and
   reapable, still running, or stalled.
6. **Things that will message this session after it closes.** Reminders
   (`~/.scripts/remind-at.sh --list`, rows pointing at `$PI_SESSION_ADDRESS`)
   and detached waiters (`pgrep -fl 'pr-wait|ci-wait'`). A reminder resumes
   this session; a waiter's message queues until it does. For each: keep,
   retarget, or cancel.
7. **Scratch.** Files under `~/scratch` written or read this session. For
   each: keep (still live), promote (where to), or delete.
8. **Sigil.** Only if this session called a sigil tool, had a
   `<sigil-board>` block, or has a session map
   (`grep '"sigil-map-run"' "$PI_SESSION_FILE" | tail -1 | jq -r .data.map`).
   `SERVER=${SIGIL_SERVER:-http://127.0.0.1:5858}`; if it is down, say so in
   one line and move on.
   - *Board:* `sigil_read` this session's board. Plan steps not marked done
     go under 1; `userChanges` the transcript never discussed go under 2.
   - *Map:* `curl -s $SERVER/maps/<id> | jq -r .text`. Its open tasks,
     questions and blockers are a second opinion from an observer model,
     not evidence: report only where they disagree with 1 and 2.
   - *Boards:* from `curl -s $SERVER/rooms`, the boards this session drew on
     (`lastWriter.agent`) and this repo's `<repo>--<branch>` boards whose
     branch is gone. For each: keep, export
     (`$SERVER/rooms/<id>/export.md`), archive, or delete.
9. **Linear.** Issues touched this session that need a state change or a
   comment with what happened. Only if Linear was in play.
10. **Carry-forward.** Only if work remains. Three to six lines a fresh
    session would need: the goal, where it stands, the next concrete step,
    the trap to avoid, the map's canvas link if one exists. Put it in the
    Linear issue or the handoff file, not only in this reply.

**Report** in that order, skipping empty sections with one "none" line. End
with lettered options, recommended one marked:
a) close here (with the cleanup from 4-8 you would run first, if any),
b) finish <the loose end>,
c) write the carry-forward to `~/scratch/<issue|topic>-handoff.md` so a
   fresh session starts with "read ~/scratch/<file> and continue",
d) hand the carry-forward to a familiar.
