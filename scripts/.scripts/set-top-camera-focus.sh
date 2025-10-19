#!/bin/bash
v4l2-ctl -d /dev/video3 --set-ctrl=focus_automatic_continuous=0
v4l2-ctl -d /dev/video3 --set-ctrl=focus_absolute=20
