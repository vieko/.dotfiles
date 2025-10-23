#!/usr/bin/env bash

# Disable system suspend for remote access with modified hypridle configuration
# Usage: disable_suspend.sh
#
# This script:
# 1. Creates a no-suspend hypridle configuration
# 2. Creates a state file to track the no-suspend mode
# 3. Masks systemd sleep targets to prevent system suspend
# 4. Restarts hypridle with the no-suspend configuration

STATE_FILE="$HOME/.no_suspend_state"
CONFIG_DIR="$HOME/.config/hypr"
TEMP_CONFIG="$CONFIG_DIR/hypridle.conf.no_suspend"
NOTIFY_TITLE="Hypridle"

# Check if we're already in no-suspend mode
if [[ -f "$STATE_FILE" ]]; then
    echo "Already in no-suspend mode for remote access"
    notify-send "$NOTIFY_TITLE" "Already in no-suspend mode for remote access"
    exit 0
fi

# Create the no-suspend configuration
create_no_suspend_config() {
    cat > "$TEMP_CONFIG" << EOF
general {
    lock_cmd = pidof hyprlock || hyprlock
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd = hyprctl dispatch dpms on
}

# === HYPRIDLE: SCREENLOCK
listener {
    timeout = 600 # 10 mins
    on-timeout = loginctl lock-session
}

# === HYPRIDLE: DPMS
listener {
    timeout = 660 # 11 mins
    on-timeout = hyprctl dispatch dpms off
    on-resume = hyprctl dispatch dpms on
}

# === HYPRIDLE: DUMMY SUSPEND (disabled)
listener {
    timeout = 999999 # Effectively disabled (11+ days)
    on-timeout = echo "Suspend prevented by no-suspend mode"
}
EOF
}

# Switch to no-suspend mode for remote access
echo "Switching to no-suspend mode for remote access"
create_no_suspend_config
touch "$STATE_FILE"

# Use the no-suspend config
killall hypridle 2>/dev/null
HYPRIDLE_CONFIG="$TEMP_CONFIG" hypridle &

# Disable system suspend via systemd (requires sudo/polkit)
if ! pkexec systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target; then
    echo "Failed to mask systemd sleep targets. You may need to run: sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target"
    notify-send "$NOTIFY_TITLE" "Failed to mask systemd sleep targets" --urgency=critical
    # Clean up since we couldn't complete the operation
    rm -f "$STATE_FILE"
    exit 1
fi

notify-send "$NOTIFY_TITLE" "No-suspend mode for remote access"