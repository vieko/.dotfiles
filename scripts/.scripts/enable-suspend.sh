#!/usr/bin/env bash

# Enable system suspend and restore normal hypridle configuration
# Usage: enable_suspend.sh
#
# This script:
# 1. Removes the no-suspend state file
# 2. Unmasks systemd sleep targets
# 3. Restarts hypridle with the normal configuration

STATE_FILE="$HOME/.no_suspend_state"
CONFIG_DIR="$HOME/.config/hypr"
TEMP_CONFIG="$CONFIG_DIR/hypridle.conf.no_suspend"
NOTIFY_TITLE="Hypridle"

# Check if we're already in normal mode
if [[ ! -f "$STATE_FILE" ]]; then
    echo "Already in normal mode with suspend enabled"
    notify-send "$NOTIFY_TITLE" "Already in normal mode with suspend enabled"
    exit 0
fi

# Switch back to normal mode with suspend
echo "Switching to normal mode with suspend enabled"

# Remove temporary config if it exists
if [[ -f "$TEMP_CONFIG" ]]; then
    rm "$TEMP_CONFIG"
fi

# Remove state file
rm "$STATE_FILE"

# Re-enable systemd suspend targets
if ! pkexec systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target; then
    echo "Failed to unmask systemd sleep targets. You may need to run: sudo systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target"
    notify-send "$NOTIFY_TITLE" "Failed to unmask systemd sleep targets" --urgency=critical
    exit 1
fi

# Restart hypridle to apply normal config
killall hypridle 2>/dev/null
hypridle &

notify-send "$NOTIFY_TITLE" "Normal mode with suspend enabled"