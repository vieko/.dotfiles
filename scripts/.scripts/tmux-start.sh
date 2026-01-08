#!/usr/bin/env bash

# Default session name based on hostname
HOSTNAME=$(hostname -s)
if [[ "$HOSTNAME" == "chaos" ]]; then
    DEFAULT_SESSION="CHAOS"
else
    DEFAULT_SESSION="PHYREXIA"
fi
TERMINAL_WINDOW="void"
EDITOR_WINDOW="altar"
RUNNER_WINDOW="invoke"
LOGS_WINDOW="coven"
LEARN_WINDOW="scry"
DOTFILES_WINDOW="arcana"

# Check if tmux is already running
if ! tmux has-session -t "$DEFAULT_SESSION" 2>/dev/null; then
     
    # Create windows
    tmux new-session -d -s "$DEFAULT_SESSION" -n "$TERMINAL_WINDOW"
    tmux new-window -t "$DEFAULT_SESSION" -n "$EDITOR_WINDOW"
    tmux new-window -t "$DEFAULT_SESSION" -n "$RUNNER_WINDOW"
    tmux new-window -t "$DEFAULT_SESSION" -n "$LOGS_WINDOW"
    tmux new-window -t "$DEFAULT_SESSION" -n "$LEARN_WINDOW"
    tmux new-window -t "$DEFAULT_SESSION" -n "$DOTFILES_WINDOW"

    # Select the first window
    tmux select-window -t "$DEFAULT_SESSION":"$EDITOR_WINDOW"
    
    # Send commands
    tmux send-keys -t "$DEFAULT_SESSION":"$DOTFILES_WINDOW" "cd ~/.dotfiles; clear" C-m
    tmux send-keys -t "$DEFAULT_SESSION":"$LOGS_WINDOW" "btop" C-m
fi

# Attach to the existing session
tmux attach-session -t "$DEFAULT_SESSION"
