#!/bin/bash

# Toggle SketchyBar visibility and adjust AeroSpace bottom gap

SKETCHYBAR="/opt/homebrew/bin/sketchybar"
AEROSPACE="/opt/homebrew/bin/aerospace"
JQ="/usr/bin/jq"
SED="/usr/bin/sed"
AEROSPACE_CONFIG="$HOME/.config/aerospace/aerospace.toml"

# Check current bar visibility
HIDDEN=$($SKETCHYBAR --query bar 2>/dev/null | $JQ -r '.hidden // "off"')

if [ "$HIDDEN" = "off" ]; then
    # Hide SketchyBar
    $SKETCHYBAR --bar hidden=on
    # Reduce AeroSpace bottom gap
    $SED -i '' 's/outer\.bottom[[:space:]]*=[[:space:]]*40/outer.bottom     = 8/' "$AEROSPACE_CONFIG"
    $AEROSPACE reload-config >/dev/null 2>&1
else
    # Show SketchyBar at bottom
    $SKETCHYBAR --bar hidden=off position=bottom topmost=window
    # Increase AeroSpace bottom gap to accommodate bar
    $SED -i '' 's/outer\.bottom[[:space:]]*=[[:space:]]*8/outer.bottom     = 40/' "$AEROSPACE_CONFIG"
    $AEROSPACE reload-config >/dev/null 2>&1
fi
