#!/bin/bash

# Get the hostname
hostname=$(hostname)

# Configuration file paths
host_config_file="$HOME/.config/hypr/host.conf"
nvidia_config_file="$HOME/.config/hypr/nvidia.conf"

# Function to set monitor configuration
set_monitor_config() {
    echo "monitor=$1" > "$host_config_file"
    hyprctl keyword monitor "$1"
}

# Function to apply NVIDIA configuration
apply_nvidia_config() {
    cat "$nvidia_config_file" >> "$host_config_file"
    hyprctl keyword source "$nvidia_config_file"
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
hyprctl keyword source "$host_config_file"
