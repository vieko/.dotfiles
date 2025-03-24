#!/bin/bash

# Default session name
DEFAULT_SESSION="SUMMONING DEMONS"
EDITOR_WINDOW="altar"
RUNNER_WINDOW="void"
DOTFILES_WINDOW="arcana"
LOGS_WINDOW="coven"
LEARN_WINDOW="cognize"

# Check if tmux is already running
if ! tmux has-session -t "$DEFAULT_SESSION" 2>/dev/null; then
     
    # Create windows
    tmux new-session -d -s "$DEFAULT_SESSION" -n "$EDITOR_WINDOW"
    tmux new-window -t "$DEFAULT_SESSION" -n "$RUNNER_WINDOW"
    tmux new-window -t "$DEFAULT_SESSION" -n "$DOTFILES_WINDOW"
    tmux new-window -t "$DEFAULT_SESSION" -n "$LOGS_WINDOW"
    tmux new-window -t "$DEFAULT_SESSION" -n "$LEARN_WINDOW"

    # Select the first window
    tmux select-window -t "$DEFAULT_SESSION":"$EDITOR_WINDOW"
    
    # Send commands
    tmux send-keys -t "$DEFAULT_SESSION":"$DOTFILES_WINDOW" "cd ~/.dotfiles; clear" C-m
fi

# Attach to the existing session
tmux attach-session
