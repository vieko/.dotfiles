#!/bin/bash

# Toggle dark and light themes for pop-os, tmux, kitty, fish and neovim.

LIGHTTHEME="catppuccin-latte"
DARKTHEME="catppuccin-mocha"
VIMCONF="$HOME/.config/init.lua/lua/vieko/plugins/catppuccin.lua"
KITTYCONF="$HOME/.config/kitty/themes.conf"
TMUXCONF="$HOME/.config/tmux/tmux.conf"
BTOPCONF="$HOME/.config/btop/btop.conf"
CURRENT_MODE=$(gsettings get org.gnome.desktop.interface color-scheme)

switch_vim_theme_inside_tmux() {
  theme_for_vim_panes=$1
  tmux list-panes -a -F '#{pane_id} #{pane_current_command}' | grep vim | cut -d ' ' -f 1 | xargs -I PANE tmux send-keys -t PANE ESCAPE \ ":set background=$theme_for_vim_panes" ENTER
}

if [ "$CURRENT_MODE" = "'prefer-dark'" ]; then
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-light' 
  gsettings set org.gnome.desktop.interface gtk-theme 'Pop'
  sed -i "s/$DARKTHEME/$LIGHTTHEME/" "$TMUXCONF" "$KITTYCONF"
  sed -i '/vim.opt.background/s/"dark"/"light"/g' "$VIMCONF" 
  sed -i 's|catppuccin_mocha.theme|catppuccin_latte.theme|' "$BTOPCONF"
  fish -c 'set -Ux FZF_DEFAULT_OPTS "\
  --color=bg+:#ccd0da,bg:#eff1f5,spinner:#dc8a78,hl:#d20f39 \
  --color=fg:#4c4f69,header:#d20f39,info:#8839ef,pointer:#dc8a78 \
  --color=marker:#dc8a78,fg+:#4c4f69,prompt:#8839ef,hl+:#d20f39"'
  if [ -n "$TMUX" ]; then
    switch_vim_theme_inside_tmux "light"
  fi
  fish -c 'fish_config theme save "Catppuccin Latte"'
else
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
  gsettings set org.gnome.desktop.interface gtk-theme 'Pop-dark'
  sed -i "s/$LIGHTTHEME/$DARKTHEME/" "$TMUXCONF" "$KITTYCONF"
  sed -i '/vim.opt.background/s/"light"/"dark"/g' "$VIMCONF" 
  sed -i 's|catppuccin_latte.theme|catppuccin_mocha.theme|' "$BTOPCONF"
  fish -c 'set -Ux FZF_DEFAULT_OPTS "\
    --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
  --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
  --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"'
  if [ -n "$TMUX" ]; then
    switch_vim_theme_inside_tmux "dark"
  fi
  fish -c 'fish_config theme save "Catppuccin Mocha"'
fi

if [ -n "$TMUX" ]; then
  tmux source "$TMUXCONF"
fi

pkill -SIGUSR2 btop
kill -SIGUSR1 $KITTY_PID
