#!/bin/bash

# Toggle SketchyBar visibility and adjust AeroSpace bottom gap

AEROSPACE_CONFIG="$HOME/.config/aerospace/aerospace.toml"

# Check current bar visibility
HIDDEN=$(sketchybar --query bar 2>/dev/null | jq -r '.hidden // "off"')

if [ "$HIDDEN" = "off" ]; then
    # Hide SketchyBar
    sketchybar --bar hidden=on
    # Reduce AeroSpace bottom gap
    sed -i '' 's/outer\.bottom[[:space:]]*=[[:space:]]*40/outer.bottom     = 8/' "$AEROSPACE_CONFIG"
    aerospace reload-config >/dev/null 2>&1
else
    # Show SketchyBar at bottom
    sketchybar --bar hidden=off position=bottom topmost=window
    # Increase AeroSpace bottom gap to accommodate bar
    sed -i '' 's/outer\.bottom[[:space:]]*=[[:space:]]*8/outer.bottom     = 40/' "$AEROSPACE_CONFIG"
    aerospace reload-config >/dev/null 2>&1
fi
