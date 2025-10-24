#!/bin/bash
# Focus the search field in System Settings
# Directly focuses the search text field without sending Cmd+F

osascript <<EOF
tell application "System Events"
    tell process "System Settings"
        try
            set frontmost to true
            -- Focus the search field (first text field in toolbar)
            tell first text field of first group of first toolbar of first window
                set focused to true
            end tell
        end try
    end tell
end tell
EOF
