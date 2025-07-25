#!/usr/bin/env bash
 
# ==> aliases for common commands
alias ls="exa"
alias la="exa -a"
alias ll="exa -alh"
alias tree="exa --tree"
alias cat="bat"
# alias find="fd"
# alias cl="clear"
# alias pn="pnpm"
# alias rm='echo "This is not the command you are looking for. Use (trash) instead!"; false'

# ==>  directory navigation
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."

# ==> git aliases
alias lz="lazygit"
alias lk="lazydocker" 
#alias ga="git add"
#alias gc="git commit"
#alias gp="git push"
#alias gs="git status"
 
# ==> alias for quick navigation
alias qcd=fcd

# ==> aliases for editors
alias summon="tmux-start.sh"
alias demons="nvim"

# ==> aliases for agents
alias opencode-dev="bun run /home/vieko/dev/opencode/packages/opencode/src/index.ts"

# ==> aliases for wallpapers
alias goat="goat-power.sh"
alias lamb="lamb-power.sh"
alias computer="devo-computer.sh"
alias goblin="devo-goblin.sh"
alias pattern="devo-pattern.sh"
alias flat="reset-background.sh"

# ==> aliases for convenience
alias agents="update-agents.sh"
