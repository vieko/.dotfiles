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

# enhanced history search
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'

eval "$(zoxide init bash)"
eval "$(fzf --bash)"
eval "$(starship init bash)"

. "$HOME/.deno/env"
. "$HOME/.cargo/env"

# source secrets
if [ -f ~/.secrets ]; then
    source ~/.secrets
fi

