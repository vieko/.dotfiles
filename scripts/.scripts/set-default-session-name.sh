#!/usr/bin/env bash
# Launch tmux with a default session name if no name is given

# Default session name based on hostname
HOSTNAME=$(hostname -s)
if [[ "$HOSTNAME" == "chaos" ]]; then
    DEFAULT_NAME="CHAOS"
elif [[ "$HOSTNAME" == "scourge" ]]; then
    DEFAULT_NAME="SCOURGE"
else
    DEFAULT_NAME="PHYREXIA"
fi

SESSION_NAME="${1:-$DEFAULT_NAME}"

tmux has-session -t "$SESSION_NAME" 2>/dev/null

if [ $? != 0 ]; then
    tmux new-session -s "$SESSION_NAME"
else
    tmux attach-session -t "$SESSION_NAME"
fi
