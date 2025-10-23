#!/usr/bin/env bash

current_layout=$(hyprctl getoption input:kb_layout | grep "str" | awk '{print $2}' | tr -d '"')
echo $current_layout
