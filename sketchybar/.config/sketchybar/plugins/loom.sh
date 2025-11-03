#!/bin/sh

# Base16 One Dark colors
BASE07=0xffc8ccd4  # Foreground
BASE08=0xffe06c75  # Red
BASE0B=0xff98c379  # Green

# Check if Loom is actively recording by detecting camera usage
# Uses a more efficient pgrep approach instead of lsof
RECORDING=0

# Check if Loom process exists and AppleCameraAssistant is running
# (AppleCameraAssistant runs when camera is in use)
if pgrep -q "Loom" && pgrep -q "AppleCameraAssistant"; then
  RECORDING=1
fi

if [ "$RECORDING" -eq 1 ]; then
  LABEL="REC"
  ICON_COLOR="$BASE08"  # Red when recording
else
  LABEL="OFF"
  ICON_COLOR="$BASE0B"  # Green when ready/off
fi

sketchybar --set "$NAME" icon="󰕧" icon.color="$ICON_COLOR" label="$LABEL" label.color="$BASE07"
