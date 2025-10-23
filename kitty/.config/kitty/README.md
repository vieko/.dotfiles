# Kitty Terminal Configuration

Cross-platform kitty configuration with OS-specific settings.

## Setup

After stowing kitty config, run the OS detection script:

```bash
cd ~/.config/kitty
./setup-os-link.sh
```

This creates `os-current.conf` symlink pointing to the correct OS config:
- `os-macos.conf` on macOS
- `os-linux.conf` on Linux

## Configuration Structure

- `kitty.conf` - Main config with defaults
- `os-macos.conf` - macOS-specific overrides (font size 13, DisplayP3, etc.)
- `os-linux.conf` - Linux-specific overrides (font size 10.5, Wayland support, etc.)
- `themes.conf` - Tinted-theming integration
- `nerd-font-symbols.conf` - Nerd Font symbol mappings

## Font Sizes

- **macOS**: 13pt (retina displays)
- **Linux**: 10.5pt (standard displays)

## Key Bindings

- `Ctrl+F5`: Set font size to 11
- `Ctrl+F6`: Set font size to 13
