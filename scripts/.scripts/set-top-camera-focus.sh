#!/usr/bin/env bash

# Script to configure top camera (Logitech StreamCam) for close-up card viewing
# Auto-detects camera by USB serial to handle device number and port changes

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

# Auto-detect top camera by USB serial (port paths change when re-cabled)
topCameraSerial="4A3AEB25"
topCameraDevice=""
for node in /sys/class/video4linux/video*; do
    # index 0 is the capture node; the USB device (with serial) is the interface's parent
    [[ "$(cat "$node/index" 2>/dev/null)" == "0" ]] || continue
    usbDevice=$(readlink -f "$node/device/..")
    if [[ "$(cat "$usbDevice/serial" 2>/dev/null)" == "$topCameraSerial" ]]; then
        topCameraDevice="/dev/$(basename "$node")"
        break
    fi
done

if [[ -z "$topCameraDevice" ]]; then
    echo "Error: Could not detect top camera (serial $topCameraSerial)"
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
