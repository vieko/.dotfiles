#!/bin/bash

# Toggle between Canadian and Programmers QWERTY keyboard layouts.
# Selects the input source directly (no Ctrl+Space; hotkey 60 is disabled in
# macos/.macos). The Swift helper is compiled once and rebuilt when edited.

SRC="$(dirname "$0")/toggle-input-source.swift"
BIN="$HOME/.cache/sketchybar/toggle-input-source"

if [ ! -x "$BIN" ] || [ "$SRC" -nt "$BIN" ]; then
  mkdir -p "$(dirname "$BIN")"
  swiftc -O "$SRC" -o "$BIN" 2>/dev/null || exit 1
fi

# The bar updates from the keyboard_change notification, not from here.
exec "$BIN"
