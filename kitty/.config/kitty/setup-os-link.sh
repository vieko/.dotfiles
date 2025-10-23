#!/usr/bin/env bash
# Create symlink to correct OS-specific config

KITTY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$(uname -s)" in
    Darwin)
        ln -sf os-macos.conf "$KITTY_DIR/os-current.conf"
        echo "✓ Linked os-current.conf → os-macos.conf"
        ;;
    Linux)
        ln -sf os-linux.conf "$KITTY_DIR/os-current.conf"
        echo "✓ Linked os-current.conf → os-linux.conf"
        ;;
    *)
        echo "✗ Unknown OS: $(uname -s)"
        exit 1
        ;;
esac
