#!/bin/sh

# The $NAME variable is passed from sketchybar and holds the name of
# the item invoking this script:
# https://felixkratz.github.io/SketchyBar/config/events#events-and-scripting

# Base16 One Dark colors
BASE07=0xffc8ccd4  # Foreground
BASE0A=0xffe5c07b  # Yellow

STATE_FILE="/tmp/sketchybar_clock_state"

# Clock icon
ICON="󰥔"  # nf-md-clock_outline

# Read state (default to 0 = time only)
if [ -f "$STATE_FILE" ]; then
    STATE=$(cat "$STATE_FILE")
else
    STATE=0
fi

# Format based on state
if [ "$STATE" = "1" ]; then
    # Date + Time format: "Nov 1 00:00"
    LABEL="$(date '+%b %-d %H:%M')"
else
    # Time only format: "00:00"
    LABEL="$(date '+%H:%M')"
fi

sketchybar --set "$NAME" icon="$ICON" icon.color="$BASE0A" label="$LABEL" label.color="$BASE07"
