#!/usr/bin/env bash
# Setup OS-specific configuration symlink for Ghostty
# Similar to Kitty's cross-platform configuration pattern

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
else
    echo "Unsupported OS: $OSTYPE"
    exit 1
fi

# Create symlink
LINK_NAME="config-current"
TARGET="config-$OS"

# Remove existing symlink if present
if [[ -L "$LINK_NAME" ]] || [[ -e "$LINK_NAME" ]]; then
    rm -f "$LINK_NAME"
fi

# Create new symlink
ln -s "$TARGET" "$LINK_NAME"

echo "Created symlink: $LINK_NAME -> $TARGET"
echo "Ghostty will now use $OS-specific configuration."
echo ""
echo "The base config includes 'config-file = config-current', so Ghostty loads"
echo "these $OS overrides automatically. Restart Ghostty to apply."
