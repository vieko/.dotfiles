#!/usr/bin/env bash

# Base16 One Dark colors
BASE0B=0xff98c379  # Green

# Check if the currently focused window is in fullscreen mode
# Query aerospace for focused window fullscreen state
FULLSCREEN=$(aerospace list-windows --focused --format "%{window-is-fullscreen}" 2>/dev/null)

if [ "$FULLSCREEN" = "true" ]; then
    # In fullscreen mode - show fullscreen icon
    ICON="󰊓"  # nf-md-fullscreen
else
    # Not in fullscreen - show fullscreen exit icon
    ICON="󰊔"  # nf-md-fullscreen_exit
fi

sketchybar --set "$NAME" icon="$ICON" icon.color="$BASE0B"
