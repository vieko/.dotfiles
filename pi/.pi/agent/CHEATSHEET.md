## Shell without a model turn

- `!git status` runs in the TUI; output lands in the transcript, so the model sees it next turn anyway. `!!cmd` runs it and keeps it out of context.
- Use it for `git status`, `gh pr checks N`, `anvil status`, `ls`, `pnpm test`.

## Steer, don't abort

- Enter while the model is streaming queues a steering message; it lands after the current assistant turn and keeps the cache warm.
- Alt+Enter queues a follow-up that lands after the run finishes.
- Alt+Up pulls queued messages back into the editor. Escape aborts and returns them too, but loses the in-flight turn.

## Branch instead of resuming a 300K context

- `/fork` (Ctrl+Shift+F) picks an earlier user message and starts a new session from there. The drift after it stays behind; pi summarizes the abandoned branch into the new one.
- `/tree` (Ctrl+Shift+T) does the same inside the current session file. Opens on user messages (`treeFilterMode: user-only`); Shift+L labels a node.
- `/clone` copies the active branch into a new session when you want two parallel continuations.
- `/new` (Ctrl+Shift+N) + `/recap` is the restart path after a long break.

## Compaction

- `/compact keep the migration plan and the open questions` compacts with instructions. Cheaper than an idle rewrite at 300K, and you get a summary to read on return.
- `/ctx` shows context cost; `/ctx drop` removes the largest tool result.

## Starting sessions

- `pi -c` continues the most recent session in this directory, no picker.
- `pi @spec.md "implement this"` seeds a fresh session with a file.
- `pi -p "question"` prints one answer and exits (no session).
- `/name <label>` makes the session findable in `/resume`; `/session` shows cost and token totals.

## Templates that earn their keep

`/issue <id>` load and stop, `/lede` PR opening line, `/pr <n>` review a PR, `/review` review staged diff, `/recap` state for a fresh contributor.

## Copy and export

- Ctrl+X copies the last assistant message (or the selection in fullscreen).
- `/export` writes HTML or JSONL; `/copy` copies the whole conversation.
- Ctrl+O expands or collapses tool output; Ctrl+G edits the prompt in nvim.

## Models

- `/model <fuzzy>` or Ctrl+L is one action; Ctrl+. cycles the six picker slots.
- Shift+Tab cycles thinking level; the editor border color shows it. Ctrl+S in the picker saves the choice as default.
