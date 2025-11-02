#!/bin/bash

# Base16 One Dark colors
BASE07=0xffc8ccd4  # Foreground
BASE0B=0xff98c379  # Green
BASE0E=0xffc678dd  # Purple

# Get current keyboard layout
LAYOUT=$(defaults read ~/Library/Preferences/com.apple.HIToolbox.plist AppleSelectedInputSources 2>/dev/null | grep "KeyboardLayout Name" | sed -E 's/.*"KeyboardLayout Name" = "?([^";]+)"?;.*/\1/')

# Always use the same icon, just change color based on layout
ICON="󰌌"  # nf-md-keyboard

case "$LAYOUT" in
  "Canadian")
    ICON_COLOR="$BASE0B"  # Green
    LABEL="CAN"
    ;;
  "Programmers QWERTY"|"U.S.")
    ICON_COLOR="$BASE0E"  # Purple
    LABEL="PRG"
    ;;
  *)
    ICON_COLOR="$BASE0B"
    LABEL="$LAYOUT"
    ;;
esac

sketchybar --set "$NAME" icon="$ICON" icon.color="$ICON_COLOR" label="$LABEL" label.color="$BASE07"
