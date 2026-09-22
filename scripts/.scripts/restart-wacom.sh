#!/usr/bin/env bash
# Restart the Wacom tablet driver on macOS

uid=$(id -u)

launchctl kickstart -k "gui/${uid}/com.wacom.wacomtablet"

echo "Wacom driver restarted."
