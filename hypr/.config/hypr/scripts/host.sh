#!/usr/bin/env bash

# HAVOC (eDP-1): 13.5" screen, 2880x1920 resolution, scale factor 2
# CHAOS (DP-2): 31.5" screen, 6016x3384 resolution (Asus PA32QCV 6K)
#
# === Laptop DPI calculation:
# Diagonal resolution: sqrt(2880² + 1920²) = 3456 pixels
# DPI = 3456 / 13.5 = 256 DPI
# Effective DPI after scaling: 256 / 2 = 128 DPI
#
#
# === Desktop DPI calculation (Asus PA32QCV):
# Diagonal resolution: sqrt(6016² + 3384²) = 6883.52 pixels
# DPI = 6883.52 / 31.5 = 218.52 DPI
# Effective DPI after scaling: 218.52 / 2 = 109.26 DPI
#
#
# === Scale factor comparison:
# Scale factor of 1.5: Effective DPI: 218.52 / 1.5 = 145.68 DPI (too large)
# Scale factor of 2.0: Effective DPI: 218.52 / 2 = 109.26 DPI (ideal, matches laptop workflow)

# ===  get the hostname
hostname=$(hostname)

# Configuration file paths
host_config_file="$HOME/.config/hypr/host.conf"
nvidia_config_file="$HOME/.config/hypr/nvidia.conf"

# === function to set monitor configuration
set_monitor_config() {
    echo "monitor=$1" > "$host_config_file"
    hyprctl keyword monitor "$1"
}

# === function to apply NVIDIA configuration
apply_nvidia_config() {
    cat "$nvidia_config_file" >> "$host_config_file"
    hyprctl keyword source "$nvidia_config_file"
}

# === main configuration logic
case "$hostname" in
    "havoc")
        set_monitor_config "eDP-1,2880x1920@120,0x0,2"
        ;;
    "chaos")
        set_monitor_config "DP-2,6016x3384@60,0x0,2"
        # apply_nvidia_config
        ;;
    *)
        echo "Unknown hostname: $hostname. Using default configuration."
        set_monitor_config ",preferred,auto,auto"
        ;;
esac

# === ensure the host configuration is loaded
hyprctl keyword source "$host_config_file"
