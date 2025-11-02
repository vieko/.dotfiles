#!/usr/bin/env bash

# Base16 One Dark colors
BASE00=0xff282c34  # Background (dark text on active workspace)
BASE07=0xffc8ccd4  # Foreground (light text on inactive workspace)

# Highlight the currently focused AeroSpace workspace

if [ "$1" = "$FOCUSED_WORKSPACE" ]; then
    sketchybar --set "$NAME" background.drawing=on label.color="$BASE00"
else
    sketchybar --set "$NAME" background.drawing=off label.color="$BASE07"
fi
