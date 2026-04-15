#!/usr/bin/env bash
# Restart AeroSpace window manager

pkill -9 AeroSpace
sleep 1
open -a AeroSpace
