# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Dotfiles Management

### Commands
- `stow .`: Symlink all dotfiles to appropriate locations
- `stow <folder>`: Symlink specific configuration folder
- `stow -t / <folder>`: Symlink system-wide configurations (may need sudo)
- `git status`: Check status of dotfiles repository
- `git diff`: View pending changes
- `git add -u`: Add modified tracked files
- `git add <file>`: Add specific file

### Style Guidelines
- **Organization**: Each application's configs belong in their own directory
- **Naming**: Use lowercase for directories and original case for config files
- **Comments**: Include brief comments for non-obvious configurations
- **Platform**: Distinguish between Linux-specific and cross-platform configs
- **Consistency**: Maintain consistent theming across applications
- **Naming Conventions**: Use camelCase for script variables
- **Shell Scripts**: Place executable scripts in the `scripts` directory
- **Environment Variables**: Define context-specific variables in respective config files

## Hyprland Configuration

### Installation
Install Hyprland manually from releases/source and hy3 using hyprpm to prevent version mismatches.

### Configuration Structure
The Hyprland config (`hypr/.config/hypr/`) uses a modular approach:
- `hyprland.conf`: Main config that sources other modules
- `host.conf`: Auto-generated host-specific monitor settings (via `scripts/host.sh`)
- `nvidia.conf`: NVIDIA GPU specific settings
- `colors.conf`: Base16 One Dark theme variables
- `screens.conf`, `mirror.conf`: Multi-monitor configurations
- `hyprlock.conf`, `hypridle.conf`: Lock screen and idle management
- `hyprpaper.conf`: Wallpaper configuration

### Host-Specific Setup
The configuration automatically adapts based on hostname:
- **havoc**: Laptop with eDP-1 display (2880x1920@120Hz, scale 2)
- **chaos**: Desktop with DP-2 display (3840x2160@160Hz, scale 1.5)

Host detection and DPI calculations are handled by `scripts/host.sh`.

### Key Dependencies
- `hy3`: Tiling plugin with tab support (install via hyprpm)
- `waybar`: Status bar
- `fuzzel`: Application launcher
- `hyprpaper`, `hypridle`, `hyprlock`: Hyprland utilities
- `hyprshot`: Screenshots
- `hyprpicker`: Color picker

### Important Scripts
- `scripts/host.sh`: Generates host-specific monitor configuration
- `scripts/gtk.sh`: Synchronizes GTK theme settings
- `scripts/xdg.sh`: Manages XDG desktop portal
- `scripts/scratchpad.sh`: Advanced scratchpad window management

External scripts referenced from `~/.scripts/`:
- `reload-waybar.sh`: Restart waybar
- `cycle-scratchpad-windows.sh`: Cycle through scratchpad windows
- `toggle-tablet-mode.sh`: Toggle artist/tablet mode

### Working with Hyprland Configs
- Reload config: `hyprctl reload` or `$mod + SHIFT + R`
- Test changes: Edit configs directly, they reload on save
- Debug issues: Check `hyprctl monitors` and `hyprctl clients`
- Wacom tablet: Configuration in `input:tablet` section, currently set to left_handed = false