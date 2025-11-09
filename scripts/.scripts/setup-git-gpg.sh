#!/bin/bash
# Setup git GPG configuration based on OS
# Creates a symlink to the appropriate OS-specific gitconfig
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

dotfilesPath="$homePath/.dotfiles/git"
gpgPath="$homePath/.scripts/gpg-wrapper.sh"
symlinkPath="$dotfilesPath/.gitconfig-os"
targetConfig=".gitconfig-$os"

# Verify the GPG wrapper exists
if [ ! -f "$gpgPath" ]; then
    echo "Error: GPG wrapper not found at $gpgPath" >&2
    echo "Make sure scripts is stowed: cd ~/.dotfiles && stow scripts" >&2
    exit 1
fi

# Verify the OS-specific gitconfig exists
if [ ! -f "$dotfilesPath/$targetConfig" ]; then
    echo "Error: OS-specific gitconfig not found: $dotfilesPath/$targetConfig" >&2
    exit 1
fi

# Create or update symlink
if [ -L "$symlinkPath" ]; then
    currentTarget=$(readlink "$symlinkPath")
    if [ "$currentTarget" = "$targetConfig" ]; then
        echo "✓ Git GPG config already correct for $os"
        exit 0
    fi
    rm "$symlinkPath"
fi

ln -s "$targetConfig" "$symlinkPath"
echo "✓ Created symlink for $os: .gitconfig-os -> $targetConfig"
echo "  GPG program: $gpgPath"
