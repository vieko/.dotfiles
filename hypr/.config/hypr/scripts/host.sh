#!/bin/bash

# Get the hostname
hostname=$(hostname)

# Configuration file paths
host_config_file="$HOME/.config/hypr/host.conf"
nvidia_config_file="$HOME/.config/hypr/nvidia.conf"

# Function to set monitor configuration
set_monitor_config() {
    local config="$1"
    echo "monitor=$config" > "$host_config_file"
    hyprctl keyword monitor "$config"
}

# Function to apply NVIDIA configuration
apply_nvidia_config() {
    # Execute each line in nvidia.conf using hyprctl
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ -n "$line" && ! "$line" =~ ^# ]]; then
            hyprctl keyword "$line"
            echo "$line" >> "$host_config_file"
        fi
    done < "$nvidia_config_file"
}

# Main configuration logic
case "$hostname" in
    "havoc")
        set_monitor_config "eDP-1,2880x1920@120,0x0,2"
        ;;
    "chaos")
        set_monitor_config "DP-2,3840x2160@160,0x0,1"
        apply_nvidia_config
        ;;
    *)
        echo "Unknown hostname: $hostname. Using default configuration."
        set_monitor_config ",preferred,auto,auto"
        ;;
esac

# Ensure the host configuration is loaded
if [ -f "$host_config_file" ]; then
    hyprctl keyword source "$host_config_file"
else
    echo "Warning: Host configuration file not found at $host_config_file"
fi
