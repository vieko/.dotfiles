#!/usr/bin/env bash

. "$CONFIG_DIR/colors.sh"

# Highlight the currently focused AeroSpace workspace
# Query aerospace directly for reliability instead of relying on env vars

FOCUSED=$(aerospace list-workspaces --focused)

if [ "$1" = "$FOCUSED" ]; then
    sketchybar --set "$NAME" background.drawing=on label.color="$BASE00"
else
    sketchybar --set "$NAME" background.drawing=off label.color="$BASE07"
fi
