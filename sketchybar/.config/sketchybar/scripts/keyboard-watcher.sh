#!/bin/bash

# Keyboard layout change watcher
# Monitors HIToolbox plist for changes and triggers sketchybar updates
# More efficient than polling every second

PLIST="$HOME/Library/Preferences/com.apple.HIToolbox.plist"
LAST_LAYOUT=""

# Get current layout
get_layout() {
  defaults read "$PLIST" AppleSelectedInputSources 2>/dev/null | \
    grep "KeyboardLayout Name" | \
    sed -E 's/.*"KeyboardLayout Name" = "?([^";]+)"?;.*/\1/' | \
    head -1
}

# Initialize
LAST_LAYOUT=$(get_layout)

# Watch for changes using fswatch (more efficient than polling)
# Falls back to polling if fswatch not available
if command -v fswatch >/dev/null 2>&1; then
  # Use fswatch for efficient file monitoring
  fswatch -0 -l 0.5 "$PLIST" | while read -d "" event; do
    CURRENT_LAYOUT=$(get_layout)
    if [ "$CURRENT_LAYOUT" != "$LAST_LAYOUT" ]; then
      LAST_LAYOUT="$CURRENT_LAYOUT"
      sketchybar --trigger keyboard_change
    fi
  done
else
  # Fallback to polling (5 second interval)
  while true; do
    sleep 5
    CURRENT_LAYOUT=$(get_layout)
    if [ "$CURRENT_LAYOUT" != "$LAST_LAYOUT" ]; then
      LAST_LAYOUT="$CURRENT_LAYOUT"
      sketchybar --trigger keyboard_change
    fi
  done
fi
