#!/bin/bash

# Manual focus mode (for close-up card viewing)
v4l2-ctl -d /dev/video1 --set-ctrl=focus_automatic_continuous=0
v4l2-ctl -d /dev/video1 --set-ctrl=focus_absolute=20
v4l2-ctl -d /dev/video1 --set-ctrl=zoom_absolute=135

# Auto focus mode (comment out manual mode above and uncomment below)
# v4l2-ctl -d /dev/video1 --set-ctrl=focus_automatic_continuous=1
# v4l2-ctl -d /dev/video1 --set-ctrl=zoom_absolute=120
