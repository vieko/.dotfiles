#!/usr/bin/env bash
# Screenshot wrapper that saves to file AND copies to clipboard

screenshotDir="$HOME/Pictures/Screenshots"
timestamp=$(date +'%Y-%m-%d_%H-%M-%S')
filename="$screenshotDir/${timestamp}_screenshot.png"

# Create directory if it doesn't exist
mkdir -p "$screenshotDir"

# Take screenshot and save to file (allows interactive selection)
hyprshot -s -o "$screenshotDir" -f "${timestamp}_screenshot.png" "$@"

# Copy to Wayland clipboard (clip2path will handle paste in Claude Code)
wl-copy --type image/png < "$filename"

notify-send "Screenshot" "Saved and copied to clipboard"
