#!/bin/bash

# Toggle between normal hypridle configuration and a no-suspend mode for remote access
# Usage: toggle_monitor.sh
#
# To check current status:
#   - Check if state file exists: [[ -f "$HOME/.no_suspend_state" ]]
#   - Check if sleep target is masked: systemctl status sleep.target
#   - View current hypridle config: cat $HOME/.config/hypr/hypridle.conf.no_suspend
#
# If no_suspend_state exists and sleep.target is masked, the script is in no-suspend mode.
# Otherwise, it's in normal mode with suspend enabled.

# TODO: resolve `the system will now suspend` issue

STATE_FILE="$HOME/.no_suspend_state"
CONFIG_DIR="$HOME/.config/hypr"
ORIG_CONFIG="$CONFIG_DIR/hypridle.conf"
TEMP_CONFIG="$CONFIG_DIR/hypridle.conf.no_suspend"

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

if [[ -f "$STATE_FILE" ]]; then
    # Switch back to normal mode with suspend
    echo "Switching to normal mode with suspend enabled"
    if [[ -f "$TEMP_CONFIG" ]]; then
        rm "$TEMP_CONFIG"
    fi
    rm "$STATE_FILE"
    
    # Re-enable systemd suspend targets
    pkexec systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target
    
    # Restart hypridle to apply normal config
    killall hypridle 2>/dev/null
    hypridle &
    
    notify-send "Hypridle" "Normal mode with suspend enabled"
else
    # Switch to no-suspend mode for remote access
    echo "Switching to no-suspend mode for remote access"
    create_no_suspend_config
    touch "$STATE_FILE"
    
    # Use the no-suspend config
    killall hypridle 2>/dev/null
    HYPRIDLE_CONFIG="$TEMP_CONFIG" hypridle &
    
    # Disable system suspend via systemd (requires sudo/polkit)
    pkexec systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
    
    notify-send "Hypridle" "No-suspend mode for remote access"
fi
