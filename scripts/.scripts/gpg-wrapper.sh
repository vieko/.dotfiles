#!/bin/bash
# GPG wrapper for cross-platform compatibility
# Works on both macOS (Homebrew) and Linux (system)

if [ -f /opt/homebrew/bin/gpg ]; then
    # macOS with Homebrew
    exec /opt/homebrew/bin/gpg "$@"
elif [ -f /usr/local/bin/gpg ]; then
    # macOS with manual install or older Homebrew
    exec /usr/local/bin/gpg "$@"
elif [ -f /usr/bin/gpg ]; then
    # Linux system GPG
    exec /usr/bin/gpg "$@"
else
    echo "Error: GPG not found in any standard location" >&2
    exit 1
fi
