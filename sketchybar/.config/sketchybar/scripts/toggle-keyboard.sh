#!/bin/bash

# Toggle between Canadian and Programmers QWERTY keyboard layouts
# REQUIRES: Accessibility permissions for SketchyBar
# (System Settings → Privacy & Security → Accessibility → Add SketchyBar)

# Switch using Control+Space keyboard shortcut
osascript -e 'tell application "System Events" to key code 49 using {control down}' 2>/dev/null

# Give it a moment to switch
sleep 0.3

# Update sketchybar
sketchybar --trigger keyboard_change
