#!/bin/sh

# Base16 One Dark colors
BASE07=0xffc8ccd4  # Foreground
BASE08=0xffe06c75  # Red
BASE0B=0xff98c379  # Green

# Check if Loom is actively recording
# Method 1: Check for camera device access (requires periodic polling)
# Method 2: Check if video capture is active by looking for specific processes
RECORDING=0

# Check if any Loom process has camera/microphone access active
# This looks for coreaudiod connections which indicate active recording
if lsof -c Loom 2>/dev/null | grep -q "AppleCameraAssistant\|coreaudiod"; then
  RECORDING=1
fi

# Alternative: check for Loom recording-related processes or windows
# If the above doesn't work reliably, we can check for CPU usage spikes in Loom
if [ "$RECORDING" -eq 1 ]; then
  LABEL="REC"
  ICON_COLOR="$BASE08"  # Red when recording
else
  LABEL="OFF"
  ICON_COLOR="$BASE0B"  # Green when ready/off
fi

sketchybar --set "$NAME" icon="󰕧" icon.color="$ICON_COLOR" label="$LABEL" label.color="$BASE07"
