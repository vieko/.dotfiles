#!/bin/bash

# Cycle SketchyBar position: bottom → hidden → top → hidden → bottom...
# Adjusts AeroSpace gaps accordingly

SKETCHYBAR="/opt/homebrew/bin/sketchybar"
AEROSPACE="/opt/homebrew/bin/aerospace"
JQ="/usr/bin/jq"
SED="/usr/bin/sed"
AEROSPACE_CONFIG="$HOME/.config/aerospace/aerospace.toml"
STATE_FILE="/tmp/sketchybar-state"

# States: 0=bottom, 1=hidden(from-bottom), 2=top, 3=hidden(from-top)
# Read current state (default to 0 if file doesn't exist)
if [ -f "$STATE_FILE" ]; then
    STATE=$(cat "$STATE_FILE")
else
    STATE=0
fi

# Advance to next state
NEXT_STATE=$(( (STATE + 1) % 4 ))
echo "$NEXT_STATE" > "$STATE_FILE"

case $NEXT_STATE in
    0)
        # Show at bottom: restore height to 20, top=8, bottom=28
        $SKETCHYBAR --bar hidden=off position=bottom topmost=window height=20
        $SED -i '' 's/outer\.bottom[[:space:]]*=[[:space:]]*8/outer.bottom     = 28/' "$AEROSPACE_CONFIG"
        ;;
    1)
        # Hide: all gaps 8
        $SKETCHYBAR --bar hidden=on
        $SED -i '' 's/outer\.bottom[[:space:]]*=[[:space:]]*28/outer.bottom     = 8/' "$AEROSPACE_CONFIG"
        ;;
    2)
        # Show at top: menu bar height (37px for notched Macs)
        $SKETCHYBAR --bar hidden=off position=top topmost=window height=37
        ;;
    3)
        # Hide: all gaps 8 (no change needed)
        $SKETCHYBAR --bar hidden=on
        ;;
esac

$AEROSPACE reload-config >/dev/null 2>&1
