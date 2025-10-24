#!/bin/bash
# Focus Spotify's search/action panel (Cmd+K)
# Sends Cmd+K directly to Spotify, bypassing Aerospace

osascript <<EOF
tell application "System Events"
    tell process "Spotify"
        set frontmost to true
        keystroke "k" using command down
    end tell
end tell
EOF
