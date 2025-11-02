#!/bin/bash

# Toggle clock format between time-only and date+time

STATE_FILE="/tmp/sketchybar_clock_state"

# Read current state (default to 0 = time only)
if [ -f "$STATE_FILE" ]; then
    STATE=$(cat "$STATE_FILE")
else
    STATE=0
fi

# Toggle state
if [ "$STATE" = "0" ]; then
    echo "1" > "$STATE_FILE"
else
    echo "0" > "$STATE_FILE"
fi

# Trigger clock update
sketchybar --trigger clock_update
