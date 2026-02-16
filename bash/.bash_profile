#!/usr/bin/env bash

# source global definitions (Linux only - macOS doesn't need this)
if [[ "$OSTYPE" == "linux-gnu"* ]] && [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# Homebrew environment (macOS only - must be early so brew-installed tools are in PATH)
if [[ "$OSTYPE" == "darwin"* ]] && [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Load fnm early for all shell types (interactive and non-interactive)
# Runs after brew shellenv so fnm is found, but prepends PATH so Node takes priority
if command -v fnm &>/dev/null; then
    eval "$(fnm env --use-on-cd)"
fi

# source the user's bashrc if it exists
if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi
. "$HOME/.cargo/env"

# Added by Hades
export PATH="$PATH:$HOME/.hades/bin"
