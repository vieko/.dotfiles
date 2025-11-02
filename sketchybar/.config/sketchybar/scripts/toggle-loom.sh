#!/bin/bash

# Toggle Loom - open if not running, activate if running

if pgrep -x "Loom" > /dev/null; then
    # Loom is running, activate it
    open -a "Loom"
else
    # Loom is not running, launch it
    open -a "Loom"
fi
