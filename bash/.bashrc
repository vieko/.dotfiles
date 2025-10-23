#!/usr/bin/env bash

# Check bash version (require 4.0+)
if ((BASH_VERSINFO[0] < 4)); then
    echo "Warning: Bash 4.0+ required for full functionality. Current version: $BASH_VERSION" >&2
    echo "On macOS: brew install bash && chsh -s /opt/homebrew/bin/bash" >&2
fi

# source additional configuration files
for file in ~/.bash_{aliases,functions,exports,prompt}; do
    [[ -r "$file" ]] && [[ -f "$file" ]] && source "$file"
done


# enable bash completion
if [[ $- == *i* ]]; then
    if [ -f /opt/homebrew/etc/profile.d/bash_completion.sh ]; then
        source /opt/homebrew/etc/profile.d/bash_completion.sh
    elif [ -f /usr/share/bash-completion/bash_completion ]; then
        source /usr/share/bash-completion/bash_completion
    fi
fi

# shell options
shopt -s autocd     # Enhanced directory navigation
shopt -s nocaseglob # Case-insensitive globbing
shopt -s histappend # Append to the history file instead of overwriting it
shopt -s cdspell    # Autocorrect typos in path names when using `cd`
shopt -s dirspell   # Autocorrect typos in path names during tab completion
shopt -s globstar   # Enable ** recursive globbing

# history settings
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoreboth:erasedups


# Optimized history handling - only append, don't reload every prompt
export PROMPT_COMMAND='history -a'

# prevents ctrl+d from exiting the shell
IGNOREEOF=10

# enhanced history search
if [[ $- == *i* ]]; then
  bind '"\e[A": history-search-backward'
  bind '"\e[B": history-search-forward'
fi

# Load fzf and starship immediately for keybindings to work (interactive shells only)
# These are fast enough and needed for interactive features
if [[ $- == *i* ]]; then
    command -v fzf &>/dev/null && eval "$(fzf --bash)"
    command -v starship &>/dev/null && eval "$(starship init bash)"
fi

# Conditionally load jj completion if jj is available
if command -v jj &>/dev/null; then
    source <(jj util completion bash)
fi

# source secrets
if [ -f ~/.secrets ]; then
    source ~/.secrets
fi


# Load fnm if available
if command -v fnm &>/dev/null; then
    eval "$(fnm env --use-on-cd)"
fi

# Generated for envman. Do not edit. (Linux only)
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    [ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"
fi

# Ensure Homebrew bin is at the front of PATH (must be after fnm/envman)
if [[ "$OSTYPE" == "darwin"* ]]; then
    export PATH="/opt/homebrew/bin:$PATH"
fi

# Load zoxide at the very end to avoid configuration issues
eval "$(zoxide init bash)"
