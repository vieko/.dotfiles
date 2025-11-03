#!/usr/bin/env bash

# Base16 One Dark colors
BASE00=0xff282c34  # Background (dark text on active workspace)
BASE07=0xffc8ccd4  # Foreground (light text on inactive workspace)

# Highlight the currently focused AeroSpace workspace
# Query aerospace directly for reliability instead of relying on env vars

FOCUSED=$(aerospace list-workspaces --focused)

if [ "$1" = "$FOCUSED" ]; then
    sketchybar --set "$NAME" background.drawing=on label.color="$BASE00"
else
    sketchybar --set "$NAME" background.drawing=off label.color="$BASE07"
fi
