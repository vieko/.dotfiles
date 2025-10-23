#!/usr/bin/env bash
# Script to start EasyEffects with a specific configuration

check_command() {
    if [ $? -ne 0 ]; then
        echo "Error: $1 failed to execute."
        exit 1
    fi
}

# stop EasyEffects if it is running
flatpak kill com.github.wwmm.easyeffects
check_command "Stopping EasyEffects"

# wait for EasyEffects to stop
sleep 1

# start EasyEffects using Flatpak
flatpak run com.github.wwmm.easyeffects --gapplication-service --load-preset /home/vieko/.config/easyeffects/output/Loudness\ Equalizer.json &
check_command "Starting EasyEffects + loading preset"

# wait for EasyEffects to start
for i in {1..10}; do
    if flatpak ps | grep -q com.github.wwmm.easyeffects; then
        break
    fi
    sleep 0.5
done

# fix clock issue with sound effects
pw-metadata -n settings 0 clock.force-quantum 2048
check_command "Fixing clock issue"

echo "EasyEffects has been started and configured successfully."
