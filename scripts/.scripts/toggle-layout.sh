#!/usr/bin/env bash

# Get the current layout using hyprctl getoption
CURRENT_LAYOUT=$(hyprctl getoption general:layout | awk '{print $2}')

# Log current layout for debugging
echo "Current layout: $CURRENT_LAYOUT" >> ~/.layout-toggle.log

# Toggle between master and dwindle layouts
if [[ "$CURRENT_LAYOUT" == "dwindle" ]]; then
    hyprctl keyword general:layout master
    echo "Switched to master layout" >> ~/.layout-toggle.log
else
    hyprctl keyword general:layout dwindle
    echo "Switched to dwindle layout" >> ~/.layout-toggle.log
fi
