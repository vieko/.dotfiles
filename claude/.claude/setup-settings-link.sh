#!/usr/bin/env bash
# Create symlink to correct host-specific config

CLAUDE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTNAME=$(hostname)

case "$HOSTNAME" in
    chaos)
        ln -sf settings-chaos.json "$CLAUDE_DIR/settings.json"
        echo "✓ Linked settings.json → settings-chaos.json"
        ;;
    phyrexia)
        ln -sf settings-phyrexia.json "$CLAUDE_DIR/settings.json"
        echo "✓ Linked settings.json → settings-phyrexia.json"
        ;;
    *)
        echo "✗ Unknown hostname: $HOSTNAME"
        echo "  Available configs: chaos, phyrexia"
        exit 1
        ;;
esac
