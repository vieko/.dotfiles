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
stow bash git kitty ghostty tmux nvim starship bat btop lazygit yazi
```

**macOS-only:**
```bash
stow macos-keyboard
```

**Linux-only (Wayland/Hyprland):**
```bash
stow hypr waybar dunst fuzzel mako rofi sway i3 polybar ptyxis
```

**After stowing ptyxis (applies palette + system monospace font):**
```bash
~/.dotfiles/ptyxis/setup-ptyxis.sh
```

**After stowing kitty (required for OS-specific settings):**
```bash
cd ~/.config/kitty && ./setup-os-link.sh
```

**After stowing ghostty (required for OS-specific settings):**
```bash
cd ~/.config/ghostty && ./setup-os-link.sh
```

**After stowing git (required for OS-specific GPG configuration):**
```bash
~/.scripts/setup-git-gpg.sh
```

**For system-wide packages:**
```bash
stow -t / <folder>  # May need sudo
```

## FRESH FEDORA INSTALL

Repos + full package set (RPM Fusion, COPRs, Hyprland stack, CLI tools, snapper):

```bash
sudo bash scripts/.scripts/fedora-fresh-install.sh
```

Machine-specific notes: `chaos-f44-setup.md`.

## REGARDING HYPRLAND

On Fedora, install from COPR `lionheartp/Hyprland` (handled by the script above). Install [hy3](https://github.com/outfoxxed/hy3) via `hyprpm` — versions must match hyprland's.

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
