#!/bin/bash
# Create a new kitty OS window (equivalent to Hyprland $mod+Return)
# Opens a new window at home directory

# Call kitty directly - creates new OS window at ~/ even if kitty is already running
/Applications/kitty.app/Contents/MacOS/kitty --single-instance --instance-group=1 --directory="$HOME" &
