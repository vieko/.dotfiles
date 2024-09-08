#!/bin/bash
# Launch tmux with a default session name if no name is given

SESSION_NAME="${1:-SUMMONING DEMONS}"

tmux has-session -t "$SESSION_NAME" 2>/dev/null

if [ $? != 0 ]; then
    tmux new-session -s "$SESSION_NAME"
else
    tmux attach-session -t "$SESSION_NAME"
fi
