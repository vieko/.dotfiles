#!/bin/bash

# Log file for debugging
LOGFILE="$HOME/.smart-focus.log"

# Direction argument passed to the script
DIRECTION=$1

# Get the window information
WINDOW_INFO=$(hyprctl activewindow)

# Check if the window is part of a group
IS_GROUPED=$(echo "$WINDOW_INFO" | grep "group:" | awk '{print $2}')

# Log the current window info and group status
echo "$(date): Active window info: $WINDOW_INFO" >> $LOGFILE
echo "$(date): Is window grouped: $IS_GROUPED" >> $LOGFILE

# Function to handle grouped windows with changegroupactive
handle_grouped_window() {
  if [[ "$DIRECTION" == "l" || "$DIRECTION" == "r" ]]; then
    echo "$(date): Window is part of a group, using changegroupactive" >> $LOGFILE
    hyprctl dispatch changegroupactive "$DIRECTION"
  else
    echo "$(date): Window is part of a group but direction is up/down, using movefocus" >> $LOGFILE
    hyprctl dispatch movefocus "$DIRECTION"
  fi
}

# Function to handle non-grouped windows with movefocus
handle_non_grouped_window() {
  echo "$(date): Window is not part of a group, using movefocus" >> $LOGFILE
  hyprctl dispatch movefocus "$DIRECTION"
}

# Main logic
if [[ "$IS_GROUPED" == "1" ]]; then
  handle_grouped_window
else
  handle_non_grouped_window
fi

# Log completion
echo "$(date): Focus handling complete." >> $LOGFILE
