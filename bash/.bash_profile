#!/usr/bin/env bash

# source global definitions (Linux only - macOS doesn't need this)
if [[ "$OSTYPE" == "linux-gnu"* ]] && [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# Load fnm early for all shell types (interactive and non-interactive)
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
