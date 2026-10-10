---
description: "Close out this session: loose ends, unreaped constructs, what carries forward"
argument-hint: "[anything you want weighed, e.g. 'we are done with 3910']"
---
Wrap this session. Answer "anything else for this session?" with evidence, not
memory. Read-only commands only; do not commit, push, or clean anything up
until I pick an option. Extra context from me: `$@`.

**Check, in this order:**

1. **Promised, not done.** Scan this conversation for things I asked for or
   you said you would do that have no result in the transcript: files to
   write, PRs to open, Linear comments, messages to other sessions, follow-up
   checks. One line each, or "none".
2. **Decisions waiting on me.** Lettered options you offered that I never
   answered, questions still open.
3. **Working tree.** `git status --short` in the cwd and in any worktree this
   session created or touched (`git worktree list`). Uncommitted or unpushed
   work, branches ahead of origin.
4. **Constructs.** `tmux list-windows -a -F '#W' | grep -E '^(fam|golem)-'`,
   `anvil status --since 1d` (skip if absent), familiars this session
   dispatched (`list_sessions` for ones still live). For each: done and
   reapable, still running, or stalled.
5. **Scratch.** Files under `~/scratch` written or read this session. For
   each: keep (still live), promote (where to), or delete.
6. **Sigil.** Only if this session called a sigil tool, had a
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
7. **Linear.** Issues touched this session that need a state change or a
   comment with what happened. Only if Linear was in play.
8. **Carry-forward.** Three to six lines a fresh session would need to
   continue: the goal, where it stands, the next concrete step, the trap to
   avoid. Add the map's canvas link if one exists. Bonfire writes its own
   summary on shutdown; this is the version in my words for the next prompt.

**Report** in that order, skipping sections that are empty with one "none"
line. End with lettered options, recommended one marked: a) close here,
b) finish <the loose end>, c) `/new` + `/recap` and continue fresh with the
carry-forward pasted in, d) hand the carry-forward to a familiar.
