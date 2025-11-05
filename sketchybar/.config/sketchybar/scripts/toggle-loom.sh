#!/bin/bash

# Toggle Loom - open if not running, activate if running
open -a "Loom"

# Update the loom widget immediately to reflect new state
sleep 0.5
sketchybar --update loom
