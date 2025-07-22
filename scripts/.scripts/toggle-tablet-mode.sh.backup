#!/bin/bash

STATE_FILE="$HOME/.config/tablet-mode"
SCRIPT_DIR="$(dirname "$0")"

# Create state file if it doesn't exist, default to absolute
if [[ ! -f "$STATE_FILE" ]]; then
    echo "absolute" > "$STATE_FILE"
fi

# Read current mode
currentMode=$(cat "$STATE_FILE")

# Toggle mode
if [[ "$currentMode" == "absolute" ]]; then
    newMode="artist"
    otd loadsettings "$SCRIPT_DIR/wacom-artist-mode.json"
else
    newMode="absolute"
    otd loadsettings "$SCRIPT_DIR/wacom-absolute-mode.json"
fi

# Update state file
echo "$newMode" > "$STATE_FILE"

# Show notification
notify-send "Tablet Mode" "Switched to $newMode mode" --icon=input-tablet
