#!/usr/bin/env bash

# source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# source additional configuration files
for file in ~/.bash_{aliases,functions,exports,prompt}; do
    [[ -r "$file" ]] && [[ -f "$file" ]] && source "$file"
done


# enable bash completion
[[ $- == *i* ]] && source /usr/share/bash-completion/bash_completion

# shell options
shopt -s autocd     # Enhanced directory navigation
shopt -s nocaseglob # Case-insensitive globbing
shopt -s histappend # Append to the history file instead of overwriting it
shopt -s cdspell    # Autocorrect typos in path names when using `cd`
shopt -s dirspell   # Autocorrect typos in path names during tab completion

# history settings
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoreboth:erasedups

# auto-reload .bashrc if changes are detected
# export PROMPT_COMMAND='history -a; history -n; . ~/.bashrc' 

# append to history file and reload history
export PROMPT_COMMAND='history -a; history -n;'

# prevents ctrl+d from exiting the shell
IGNOREEOF=10

# enhanced history search
if [[ $- == *i* ]]; then
  bind '"\e[A": history-search-backward'
  bind '"\e[B": history-search-forward'
fi

eval "$(zoxide init bash)"
eval "$(fzf --bash)"
eval "$(starship init bash)"

# Load deno environment if it exists
if [ -f "$HOME/.deno/env" ]; then
    . "$HOME/.deno/env"
fi

# Load cargo environment if not already in PATH
if ! [[ "$PATH" =~ "$HOME/.cargo/bin" ]]; then
    [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
fi

# source secrets
if [ -f ~/.secrets ]; then
    source ~/.secrets
fi


# Generated for envman. Do not edit.
[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"

