#!/bin/bash

# Toggle between Canadian and Programmers QWERTY keyboard layouts

# Get current layout
CURRENT=$(defaults read ~/Library/Preferences/com.apple.HIToolbox.plist AppleSelectedInputSources 2>/dev/null | grep "KeyboardLayout Name" | sed -E 's/.*"KeyboardLayout Name" = "?([^";]+)"?;.*/\1/')

# Toggle to the other layout using keyboard shortcut simulation
# macOS uses Control+Space or Control+Option+Space to switch input sources
osascript -e 'tell application "System Events" to key code 49 using {control down}'

# Give it a moment to switch
sleep 0.2

# Update sketchybar
sketchybar --trigger keyboard_change
