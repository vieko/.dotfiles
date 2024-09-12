#!/bin/bash

# restart wireplumber, pipewire and pulse
systemctl --user restart wireplumber pipewire pipewire-pulse

# reset pulseaudio confi
rm -r ~/.config/pulse

# restart easyeffects
flatpak kill com.github.wwmm.easyeffects

# wait for easyeffects to close
sleep 1

# start easyeffects in the background
flatpak run com.github.wwmm.easyeffects &

# wait for easyeffects to start
sleep 2

# run easyeffects command to set the correct output
pw-metadata -n settings 0 clock.force-quantum 2048
