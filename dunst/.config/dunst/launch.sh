#!/usr/bin/env bash

# close any running dunst processes
pidof dunst && killall dunst

# start dunst in the background
dunst &
