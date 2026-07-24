# Hyprland Configuration

## Installation

On Fedora: COPR `lionheartp/Hyprland` (see `scripts/.scripts/fedora-fresh-install.sh`). Install hy3 via `hyprpm`; its version must match hyprland's.

## Configuration Structure

The Hyprland config (`hypr/.config/hypr/`) uses a modular approach:

- `hyprland.conf`: Main config that sources other modules
- `host.conf`: Auto-generated host-specific monitor settings (via `hypr/.config/hypr/scripts/host.sh`)
- `nvidia.conf`: NVIDIA GPU specific settings
- `colors.conf`: Base16 One Dark theme variables
- `screens.conf`, `mirror.conf`: Multi-monitor configurations
- `hyprlock.conf`, `hypridle.conf`: Lock screen and idle management
- `hyprpaper.conf`: Wallpaper configuration

## Host-Specific Setup

The configuration automatically adapts based on hostname:

- **havoc**: Laptop with eDP-1 display (2880x1920@120Hz, scale 2)
- **chaos**: Desktop with DP-2 display — Asus PA32QCV 6K (6016x3384@60Hz, scale 2)

Host detection and DPI calculations are handled by `hypr/.config/hypr/scripts/host.sh`.

## Key Dependencies

- `hy3`: Tiling plugin with tab support (install via hyprpm)
- `waybar`: Status bar
- `fuzzel`: Application launcher
- `hyprpaper`, `hypridle`, `hyprlock`: Hyprland utilities
- `hyprshot`: Screenshots
- `hyprpicker`: Color picker

## Important Scripts

- `hypr/.config/hypr/scripts/host.sh`: Generates host-specific monitor configuration
- `hypr/.config/hypr/scripts/gtk.sh`: Synchronizes GTK theme settings
- `hypr/.config/hypr/scripts/xdg.sh`: Manages XDG desktop portal
- `hypr/.config/hypr/scripts/scratchpad.sh`: Advanced scratchpad window management

External scripts referenced from `~/.scripts/`:

- `reload-waybar.sh`: Restart waybar
- `cycle-scratchpad-windows.sh`: Cycle through scratchpad windows
- `toggle-tablet-mode.sh`: Toggle artist/tablet mode

## Working with Hyprland Configs

- Reload config: `hyprctl reload` or `$mod + SHIFT + R`
- Test changes: Edit configs directly, they reload on save
- Debug issues: Check `hyprctl monitors` and `hyprctl clients`
- Wacom tablet: Configuration in `input:tablet` section, currently set to left_handed = false



