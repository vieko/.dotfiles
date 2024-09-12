#!/bin/bash

# Default session name
DEFAULT_SESSION="SUMMONING DEMONS"

# Check if tmux is already running
if ! tmux has-session 2>/dev/null; then
    # No sessions exist, so create a new one with the default name
    tmux new-session -d -s "$DEFAULT_SESSION"
fi

# Attach to the existing session (whether it's the one we just created or a pre-existing one)
tmux attach-session
