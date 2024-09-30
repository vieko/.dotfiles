#!/usr/bin/env bash

polybar-msg cmd quit
# killall -q polybar
 
if type "xrandr"; then
  for m in $(xrandr --query | grep " connected" | cut -d" " -f1); do
    MONITOR=$m polybar --reload chaos &
  done
else
  polybar --reload chaos &
fi
