# My dotfiles using stow since 2024

## REQUIREMENTS

- git
- stow

## INSTALLATION

```bash
git clone git@github.com:vieko/.dotfiles.git
cd .dotfiles
```

### Stowing Configurations

Stow individual packages based on your OS and needs:

**Cross-platform (macOS + Linux):**
```bash
stow bash git kitty tmux nvim starship bat btop lazygit yazi
```

**macOS-only:**
```bash
stow macos-keyboard
```

**Linux-only (Wayland/Hyprland):**
```bash
stow hypr waybar dunst fuzzel mako rofi sway i3 polybar
```

**After stowing kitty (required for OS-specific settings):**
```bash
cd ~/.config/kitty && ./setup-os-link.sh
```

**For system-wide packages:**
```bash
stow -t / <folder>  # May need sudo
```

## REGARDING HYPRLAND

To prevent breaking hyprland when updating other packages, install [hyprland](https://wiki.hyprland.org/Getting-Started/Installation/) manually (from releases or from source) and [hy3](https://github.com/outfoxxed/hy3) using `hyprpm`. Make sure versions match!

## KINESIS LAYOUT

![Kinesis](https://github.com/vieko/.dotfiles/blob/main/assets/Screenshots/kinesis-layout.png)

## VOYAGER LAYOUT

![Voyager](https://github.com/vieko/.dotfiles/blob/main/assets/Screenshots/voyager-layout.png)

## TODOS

### GENERAL

- CONSOLIDATE keymaps between Zed and Neovim
- ADD keybindings for keyboard layout switch
- SET UP Bluetooth properly
- SET UP wifi and vpn properly

### CHAOS

- UPDATE waybar to show ethernet

### HAVOC

- UPDATE waybar to show connected interface
