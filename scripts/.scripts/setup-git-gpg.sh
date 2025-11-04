#!/bin/bash
# Setup git GPG program path based on OS
# Run this when switching between macOS and Linux

set -e

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    os="macos"
    homePath="/Users/$USER"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    os="linux"
    homePath="/home/$USER"
else
    echo "Error: Unsupported OS type: $OSTYPE" >&2
    exit 1
fi

gpgPath="$homePath/.scripts/gpg-wrapper.sh"

# Verify the GPG wrapper exists
if [ ! -f "$gpgPath" ]; then
    echo "Error: GPG wrapper not found at $gpgPath" >&2
    echo "Make sure scripts is stowed: cd ~/.dotfiles && stow scripts" >&2
    exit 1
fi

# Update git config
currentPath=$(git config --global --get gpg.program || echo "")
if [ "$currentPath" = "$gpgPath" ]; then
    echo "✓ Git GPG path already correct for $os: $gpgPath"
else
    git config --global gpg.program "$gpgPath"
    echo "✓ Updated git GPG path for $os: $gpgPath"
fi
