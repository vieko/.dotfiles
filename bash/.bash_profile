#!/usr/bin/env bash

# source global definitions (Linux only - macOS doesn't need this)
if [[ "$OSTYPE" == "linux-gnu"* ]] && [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# source the user's bashrc if it exists
if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi
. "$HOME/.cargo/env"
