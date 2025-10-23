#!/bin/bash
# Installation script for Real Programmers Qwerty keyboard layout

set -e

LAYOUT_FILE="RealProgQwerty.keylayout"
INSTALL_DIR="$HOME/Library/Keyboard Layouts"

echo "Installing Real Programmers Qwerty keyboard layout..."

# Create directory if it doesn't exist
mkdir -p "$INSTALL_DIR"

# Copy layout file
cp "$LAYOUT_FILE" "$INSTALL_DIR/"

echo "✓ Layout file installed to: $INSTALL_DIR/$LAYOUT_FILE"
echo ""
echo "Next steps:"
echo "1. Log out and log back in (or restart)"
echo "2. Go to System Settings → Keyboard → Input Sources"
echo "3. Click '+' to add a new input source"
echo "4. Search for 'Real Programmers Qwerty'"
echo "5. Add it and select it from the menu bar"
echo ""
echo "Note: You may need to enable 'Show Input menu in menu bar' to switch layouts easily"
