set fish_greeting

# PATH
# set -g -x TERM xterm-kitty
set -Ux PAGER most
set -Ux MANPAGER most
set -Ux EDITOR nvim
set -Ux VISUAL nvim
set -Ux TMPDIR /home/vieko/tmp

# CURSORS
# set fish_cursor_default block

# XDG
set -q XDG_CONFIG_HOME || set -U XDG_CONFIG_HOME $HOME/.config

# DOTFILES
alias dot='/usr/bin/git --git-dir=$HOME/.dotfiles_bare/ --work-tree=$HOME'

# GENERAL
alias y="xclip -selection clipboard -in"
alias p="xclip -selection clipboard -out"

# CONVENIENCE
alias fd="fdfind"
alias rm="trash"
alias st="fast"
alias bottom="btm"
alias lg="lazygit"
alias fa="list_aliases"
alias sc="source ~/.config/fish/config.fish"
alias cl="clear"
alias re="reset"
alias pn="pnpm"
alias upn="~/.config/functions/update-pnpm.sh"
alias prog="setxkbmap real-prog-qwerty"
alias keys="setxkbmap us"
alias fefx="~/.config/functions/reset-easyeffects.sh"
alias bose="bluetoothctl connect AC:BF:71:CD:94:76"

# EDITOR
alias vi='NVIM_APPNAME="init.lua" nvim'
alias vim='NVIM_APPNAME="init.lua" nvim'
alias demons='NVIM_APPNAME="init.lua" nvim'
alias summon="~/.config/functions/set-default-session-name.sh"

# APT
alias apt="sudo apt-get"
alias cs="sudo apt-cache search"

# CLOUDOPS
alias gam="bin/gam/gam"
alias iftop="sudo iftop"
alias iotop="sudo iotop"

# APPIMAGES
alias heptabase="nohup ~/AppImages/Heptabase.AppImage >/dev/null 2>&1 disown"

# FIXES
alias toggledns="~/.config/functions/toggle-dns.sh"
alias toggletheme="~/.config/functions/toggle-theme.sh"
alias resetaudio="~/.config/functions/reset-audio.sh"

# GAMES
alias chessx="nohup ~/Documents/Chess/Apps/chessx/release/chessx >/dev/null 2>&1 disown"

# PYTHON
pyenv init - | source
alias py="python3"
alias snake="python3"
alias python="python3"

# pnpm
set -gx PNPM_HOME "/home/vieko/.local/share/pnpm"
if not string match -q -- $PNPM_HOME $PATH
  set -gx PATH "$PNPM_HOME" $PATH
end
# pnpm end
