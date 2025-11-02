#!/usr/bin/env bash

# Script to configure top camera (Logitech StreamCam) for close-up card viewing
# Auto-detects camera by USB port to handle device number changes

# Parse command-line arguments
enableZoom=true

usage() {
    echo "Usage: $0 [--no-zoom]"
    echo "  --no-zoom    Disable zoom (sets zoom to 100 instead of 135)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-zoom)
            enableZoom=false
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Auto-detect top camera by USB port (6.3)
topCameraDevice=$(v4l2-ctl --list-devices 2>/dev/null | \
    grep -A 3 "Logitech StreamCam.*6\.3" | \
    grep -m 1 "/dev/video" | \
    awk '{print $1}')

if [[ -z "$topCameraDevice" ]]; then
    echo "Error: Could not detect top camera (USB port 6.3)"
    echo "Available devices:"
    v4l2-ctl --list-devices
    exit 1
fi

echo "Detected top camera: $topCameraDevice"

# Set manual focus mode for close-up viewing
v4l2-ctl -d "$topCameraDevice" --set-ctrl=focus_automatic_continuous=0
v4l2-ctl -d "$topCameraDevice" --set-ctrl=focus_absolute=20

# Set zoom based on flag
if [[ "$enableZoom" == true ]]; then
    v4l2-ctl -d "$topCameraDevice" --set-ctrl=zoom_absolute=135
    echo "Configured: Manual focus (close-up), zoom enabled (135)"
else
    v4l2-ctl -d "$topCameraDevice" --set-ctrl=zoom_absolute=100
    echo "Configured: Manual focus (close-up), zoom disabled (100)"
fi
