#!/bin/bash

# HAVOC (eDP-1): 13.5" screen, 2880x1920 resolution, scale factor 2
# CHAOS (DP-2): 27" screen, 3840x2160 resolution
# 
# === Laptop DPI calculation:
# Diagonal resolution: sqrt(2880² + 1920²) = 3456 pixels
# DPI = 3456 / 13.5 = 256 DPI
# Effective DPI after scaling: 256 / 2 = 128 DPI
#
#
# === Desktop DPI calculation:
# Diagonal resolution: sqrt(3840² + 2160²) = 4406.72 pixels
# DPI = 4406.72 / 27 = 163.21 DPI
#
#
# === Scale factor = Desktop DPI / Target DPI
# = 163.21 / 128
# ≈ 1.275
#
# Scale factor of 1.25: Effective DPI: 163.21 / 1.25 = 130.57 DPI
# Scale factor of 1.5: Effective DPI: 163.21 / 1.5 = 108.81 DPI

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
        set_monitor_config "DP-2,3840x2160@160,0x0,1.5"
        # apply_nvidia_config
        ;;
    *)
        echo "Unknown hostname: $hostname. Using default configuration."
        set_monitor_config ",preferred,auto,auto"
        ;;
esac

# === ensure the host configuration is loaded
hyprctl keyword source "$host_config_file"
