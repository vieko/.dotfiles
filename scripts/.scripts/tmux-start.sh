#!/usr/bin/env bash

# Default session name based on hostname
HOSTNAME=$(hostname -s)
if [[ "$HOSTNAME" == "chaos" ]]; then
    DEFAULT_SESSION="CHAOS"
elif [[ "$HOSTNAME" == "scourge" ]]; then
    DEFAULT_SESSION="SCOURGE"
else
    DEFAULT_SESSION="PHYREXIA"
fi
TERMINAL_WINDOW="void"

# Create the session with a single named window if it doesn't exist.
# Additional windows get auto-named from the catalog in
# tmux-name-window.sh (window-linked hook).
if ! tmux has-session -t "$DEFAULT_SESSION" 2>/dev/null; then
    tmux new-session -d -s "$DEFAULT_SESSION" -n "$TERMINAL_WINDOW"
fi

# Attach to the existing session
tmux attach-session -t "$DEFAULT_SESSION"
