#!/usr/bin/env bash
 
# ==> aliases for common commands
alias ls="eza"
alias la="eza -a"
alias ll="eza -alh"
alias tree="eza --tree"
alias cat="bat"

# ==>  directory navigation
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."

# ==> git aliases
alias lz="lazygit"
alias lk="lazydocker"

# ==> alias for quick navigation
alias qcd=fcd

# ==> aliases for editors
alias summon="tmux-start.sh"
alias demons="nvim"

# ==> aliases for wallpapers (Linux/Hyprland only)
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    alias goat="goat-power.sh"
    alias lamb="lamb-power.sh"
    alias computer="devo-computer.sh"
    alias goblin="devo-goblin.sh"
    alias pattern="devo-pattern.sh"
    alias flat="reset-background.sh"
fi

# ==> aliases for convenience
alias ccu="npx ccusage@latest"

# ==> macOS-only service restarts
if [[ "$OSTYPE" == "darwin"* ]]; then
    alias wacom="restart-wacom.sh"
    alias aero="restart-aerospace.sh"
fi

# ==> 1Password env injection — resolves op:// refs into child-process env only
if command -v op &>/dev/null; then
    alias opr='op run --env-file=$HOME/.dotfiles/bash/env.op --'
fi
