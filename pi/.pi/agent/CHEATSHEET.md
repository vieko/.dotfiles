## Shell

- `!cmd` runs in the TUI, no model turn; output lands in context.
- `!!cmd` same, kept out of context.

## While the model is working

- Enter: steer, lands after this turn.
- Alt+Enter: follow-up, lands after the run.
- Alt+Up: pull queued messages back. Escape: abort, loses the turn.

## Branching

- `/fork` (Ctrl+Shift+F): new session from an earlier prompt; drift stays behind.
- `/tree` (Ctrl+Shift+T): same, inside this session. Shift+L labels a node.
- `/clone`: copy the active branch to a new session.
- `/new` (Ctrl+Shift+N) + `/recap`: restart after a long break.

## Context

- `/compact <what to keep>`: compact with instructions.
- `/ctx`: context cost. `/ctx drop`: remove the largest tool result.

## Sessions

- `pi -c`: continue the latest session here. `pi @spec.md "..."`: seed with a file.
- `pi -p "..."`: one answer, no session.
- `/name <label>`: findable in `/resume`. `/session`: cost and tokens.

## Templates

- `/issue <id>`: load the issue, warm context, stop.
- `/lede`: PR opening line, two candidates.
- `/pr <n>`: review a PR.
- `/review`: review the staged diff.
- `/recap`: repo state for a fresh start.

## Copy, export, view

- Ctrl+X: copy last reply. `/copy`: whole conversation. `/export`: HTML or JSONL.
- Ctrl+O: expand tool output. Ctrl+G: edit prompt in nvim.

## Models

- `/model <fuzzy>` or Ctrl+L: pick. Ctrl+.: cycle.
- Shift+Tab: thinking level (border color). Ctrl+S in a picker: save as default.
