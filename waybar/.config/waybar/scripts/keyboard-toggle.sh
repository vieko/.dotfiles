#!/usr/bin/env bash

current_layout=$(hyprctl getoption input:kb_layout | grep "str" | awk '{print $2}' | tr -d '"')

if [ "$current_layout" = "us" ]; then
    hyprctl keyword input:kb_layout real-prog-qwerty
else
    hyprctl keyword input:kb_layout us
fi

# Send signal to Waybar to update the module
pkill -SIGRTMIN+1 waybar
