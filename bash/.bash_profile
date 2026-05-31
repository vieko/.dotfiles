#!/usr/bin/env bash

# Login-shell entrypoint. Env / PATH / one-time auth lives here.
#
# Rule of thumb (established sessions 12 & 14):
#   - .bash_profile  -> runs once per login shell. Env vars, PATH mutations,
#                       1Password secret hydration, version-manager init.
#                       Inherited by every child shell (tmux panes, subshells,
#                       Pi's `bash -c` invocations).
#   - .bashrc        -> runs per interactive shell. Aliases, prompt, completion,
#                       anything that must re-apply in every pane.
#
# Putting env/PATH here (not in .bashrc) means tmux panes inherit the resolved
# environment instead of re-running expensive bootstrap (op inject, fnm env,
# brew shellenv) on every new pane.

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

# Pre-load 1Password-managed secrets into the shell env.
# Source of truth: ~/.dotfiles/bash/env.op (op:// refs only, safe to commit).
#
# This lives in .bash_profile (login shells only), not .bashrc, so it runs
# once per terminal session — not per pane. tmux/subshells inherit the
# resolved env from the login shell instead of re-running `op inject`,
# which avoids re-prompting for 1Password authorization on every pane.
#
# NOTE: this only works if tmux is configured with `default-command` set
# to a non-login $SHELL invocation (see ~/.dotfiles/tmux/.config/tmux/
# tmux.conf). With tmux's stock default (empty default-command), every
# pane is a login shell, this block re-runs, and the 1Password desktop
# app re-prompts on every split.
if command -v op &>/dev/null \
        && [[ -r "$HOME/.dotfiles/bash/env.op" ]] \
        && op account list &>/dev/null 2>&1; then
    set -a
    eval "$(op inject -i "$HOME/.dotfiles/bash/env.op" 2>/dev/null)"
    set +a
fi

# source the user's bashrc if it exists
if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi
. "$HOME/.cargo/env"

# Added by Hades
case ":$PATH:" in
  *":$HOME/.hades/bin:"*) ;;
  *) export PATH="$PATH:$HOME/.hades/bin" ;;
esac

. "$HOME/.local/share/../bin/env"

# BEGIN: socket firewall aliases (managed by Iru)
#alias npm="sfw npm"
#alias pnpm="sfw pnpm"
#alias bun="sfw bun"
# END: socket firewall aliases (managed by Iru)
