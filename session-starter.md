# Session Starter - macOS Configuration

This document summarizes the work completed on macOS configuration (SketchyBar, AeroSpace, Karabiner, and system defaults) since the last commit. Use this as context for future sessions.

## macOS System Defaults Configuration

### Setup Location
- Main script: `macos/.macos`
- Stowable to home directory: `~/.macos`

### Installation Steps
```bash
stow macos
~/.macos
# Enter password when prompted for system-level changes
```

### Configured Settings

#### Computer Name
```bash
sudo scutil --set ComputerName "phyrexia"
sudo scutil --set HostName "phyrexia"
sudo scutil --set LocalHostName "phyrexia"
sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string "phyrexia"
```

#### Window Management
- Reduce window resize time (QuartzDebug)
- Minimize window transparency
- Reduce shadows for screenshots

#### Screenshots
- Disable shadows in screenshots: `defaults write com.apple.screencapture disable-shadow -bool true`
- Save location: `~/Pictures/Screenshots`
- Format: PNG (default)

#### Notes
- Based on [Mathias Bynens' dotfiles](https://github.com/mathiasbynens/dotfiles/blob/main/.macos)
- Safe to run multiple times
- Groups related settings under section headers
- Some changes require logout/restart to take effect

## SketchyBar Setup

### Installation
- Installed via Homebrew: `brew install sketchybar`
- Font installed: `brew install --cask font-sf-mono-nerd-font-ligaturized`
- Service enabled to start at login: `brew services start sketchybar`
- Screen Recording permissions granted for menu bar integration

### Configuration Location
- Main config: `sketchybar/.config/sketchybar/sketchybarrc`
- Plugins: `sketchybar/.config/sketchybar/plugins/`
- Scripts: `sketchybar/.config/sketchybar/scripts/`

### Bar Settings
- **Position**: Bottom of screen
- **Height**: 32px
- **Font**: SF Mono Nerd Font (Ligaturized) - `LigaSFMonoNerdFont`
- **Theme**: Base16 One Dark colors
- **Topmost**: `window` (appears above window shadows)
- **Toggle**: Cmd+Esc hides/shows bar (via Karabiner)

### Color Scheme (Base16 One Dark)
```bash
BASE00=0xff282c34  # Background
BASE07=0xffc8ccd4  # Foreground
BASE08=0xffe06c75  # Red (critical states, Loom icon)
BASE09=0xffd19a66  # Orange (warnings)
BASE0A=0xffe5c07b  # Yellow
BASE0B=0xff98c379  # Green (volume, clock, keyboard)
BASE0D=0xff61afef  # Blue (active workspace)
BASE0E=0xffc678dd  # Purple (battery icon, Programmers QWERTY)
```

## Left Side: AeroSpace Workspace Indicators

### Implementation
- Shows all workspaces 1-10
- Dynamically highlights active workspace
- Click to switch workspaces
- Updates via `aerospace_workspace_change` event

### Styling
- **Active workspace**: Blue background (#61afef) with dark text
- **Inactive workspaces**: Transparent background with light text
- **Fixed width**: 30px with centered labels (label.align=center, label.width=30)
- **Icon**: None (icon.drawing=off)

### Plugin: `plugins/aerospace.sh`
- Triggered by AeroSpace workspace changes
- Sets background.drawing=on for active workspace
- Resets label colors appropriately

### AeroSpace Integration
File: `aerospace/.config/aerospace/aerospace.toml`
```toml
exec-on-workspace-change = ['/bin/bash', '-c',
    'sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE'
]
```

## Right Side: System Information & Controls

### 1. Loom Toggle
- **Icon**: 󰕧 (nf-md-video) in red
- **Action**: Click to launch/activate Loom
- **Script**: `scripts/toggle-loom.sh`
- **No label**: label.drawing=off

### 2. Keyboard Layout Indicator
- **Icon**: 󰌌 (nf-md-keyboard)
- **Colors**:
  - Green for Canadian layout (CAN)
  - Purple for Programmers QWERTY (PRG)
- **Action**: Click to toggle between layouts
- **Scripts**:
  - `plugins/keyboard.sh` - displays current layout
  - `scripts/toggle-keyboard.sh` - switches layouts via Control+Space
- **Update frequency**: 5 seconds
- **Event**: `keyboard_change`

### 3. Clock
- **Icon**: 󰥔 (nf-md-clock) in green
- **Formats**:
  - Default: `HH:MM` (e.g., "22:30")
  - Alt: `MMM D HH:MM` (e.g., "Nov 1 22:30")
- **Action**: Click to toggle between formats
- **Scripts**:
  - `plugins/clock.sh` - displays time based on state
  - `scripts/toggle-clock.sh` - toggles format state
- **State file**: `/tmp/sketchybar_clock_state`
- **Update frequency**: 10 seconds
- **Event**: `clock_update`

### 4. Volume
- **Icons**: 󰕾/󰖀/󰕿/󰖁 (Nerd Font volume icons) in green
- **Label**: Percentage (e.g., "50%")
- **Script**: `plugins/volume.sh`
- **Event**: `volume_change` (system event)

### 5. Battery
- **Icons**: Nerd Font Material Design battery icons
  - 󰁹 Full (90-100%)
  - 󰂀 80% (60-89%)
  - 󰁾 50% (30-59%)
  - 󰁻 20% (10-29%)
  - 󰂎 Alert (<10%)
  - 󰂄 Charging (when plugged in)
- **Colors**:
  - Purple: Normal/Charging
  - Orange: Warning (<30%)
  - Red: Critical (<15%)
- **Label**: Always shows percentage (e.g., "95%")
- **Script**: `plugins/battery.sh`
- **Update frequency**: 120 seconds
- **Events**: `system_woke`, `power_source_change`

## AeroSpace Configuration Changes

File: `aerospace/.config/aerospace/aerospace.toml`

### Floating Windows
Added to always float (not tile):
```toml
[[on-window-detected]]
if.app-id = 'org.pqrs.Karabiner-Elements.Settings'
run = ['layout floating']

[[on-window-detected]]
if.app-id = 'org.pqrs.Karabiner-EventViewer'
run = ['layout floating']

[[on-window-detected]]
if.app-id = 'com.apple.weather.menu'
run = ['layout floating']

# Note: com.apple.FontBook was also added by user
```

### Bottom Gap
Set to 40px to accommodate SketchyBar:
```toml
[gaps]
outer.bottom = 40  # Changed from 8 to 40
```

### SketchyBar Integration
```toml
exec-on-workspace-change = ['/bin/bash', '-c',
    'sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE'
]
```

## Karabiner Configuration Changes

File: `karabiner/.config/karabiner/karabiner.json`

### Simple Modifications
```json
"simple_modifications": [
    {
        "from": { "key_code": "caps_lock" },
        "to": [{ "key_code": "left_control" }]
    }
]
```

### Cmd+Escape → Toggle SketchyBar
- **Behavior**: Toggles between visible (bottom) and completely hidden
- **Script**: `karabiner/.config/karabiner/scripts/toggle-sketchybar.sh`
- **AeroSpace adjustment**: Changes bottom gap between 40px (visible) and 8px (hidden)
- **Implementation**: Uses `hidden=on/off` (not `position=off`)
- **Note**: Karabiner needs restart after script changes

## Key Scripts

### Toggle SketchyBar (`scripts/toggle-sketchybar.sh`)
```bash
# Checks bar.hidden property (not position)
# Uses hidden=on to hide, hidden=off to show at bottom
# Adjusts aerospace bottom gap accordingly
# Also updates aerospace config file and reloads
```

### Toggle Keyboard (`scripts/toggle-keyboard.sh`)
```bash
# Simulates Control+Space to cycle input sources
# Triggers keyboard_change event for display update
```

### Toggle Clock (`scripts/toggle-clock.sh`)
```bash
# Toggles state in /tmp/sketchybar_clock_state
# Triggers clock_update event
```

### Toggle Loom (`scripts/toggle-loom.sh`)
```bash
# Opens/activates Loom application via open -a
```

## Important Notes & Lessons Learned

### Menu Bar Aliases Don't Work
Attempted to use SketchyBar's alias feature to mirror native menu bar items (1Password, Tailscale, etc.), but they don't work with `position=bottom` - menus open downward (off-screen) instead of upward. These were removed from the config.

### Simplified Workspace Display
Initially implemented dynamic hide/show for empty workspaces using `aerospace list-windows --workspace --count` and `update_freq=2`, but this caused the active workspace highlight to disappear after 2 seconds (because `$FOCUSED_WORKSPACE` wasn't available during periodic updates). Simplified to always show all 10 workspaces - much more reliable.

### Hidden vs Position
SketchyBar only accepts `position=top` or `position=bottom`. To hide the bar completely, use `hidden=on`, NOT `position=off` (which defaults to top and caused the bar to toggle between top and bottom).

### macOS Modifier Key Conflicts
Karabiner-Elements warned about macOS native modifier key remapping conflicting with Karabiner. Resolved by clearing macOS System Settings → Keyboard → Modifier Keys for Karabiner DriverKit VirtualHIDKeyboard.

## Cross-Platform Documentation

Updated `CLAUDE.md`:
```markdown
**macOS-only:** macos, macos-keyboard, aerospace, sketchybar
```

Also added macOS Defaults Configuration section to CLAUDE.md with setup instructions.

## Files Modified/Created

### New Files
- `macos/.macos` - System defaults script
- `sketchybar/.config/sketchybar/sketchybarrc`
- `sketchybar/.config/sketchybar/plugins/aerospace.sh`
- `sketchybar/.config/sketchybar/plugins/battery.sh`
- `sketchybar/.config/sketchybar/plugins/clock.sh`
- `sketchybar/.config/sketchybar/plugins/volume.sh`
- `sketchybar/.config/sketchybar/plugins/keyboard.sh`
- `sketchybar/.config/sketchybar/scripts/toggle-keyboard.sh`
- `sketchybar/.config/sketchybar/scripts/toggle-clock.sh`
- `sketchybar/.config/sketchybar/scripts/toggle-loom.sh`
- `sketchybar/.config/sketchybar/scripts/toggle-sketchybar.sh`
- `scripts/.scripts/toggle-sketchybar.sh` (duplicate in scripts dir)

### Modified Files
- `aerospace/.config/aerospace/aerospace.toml` - Added SketchyBar integration, floating rules, bottom gap 40
- `karabiner/.config/karabiner/karabiner.json` - Added Caps Lock remap, Cmd+Esc binding
- `karabiner/.config/karabiner/assets/complex_modifications/system_shortcuts.json` - Updated Cmd+Esc from Mission Control to SketchyBar toggle
- `karabiner/.config/karabiner/scripts/toggle-sketchybar.sh` - Created/updated for Cmd+Esc
- `CLAUDE.md` - Added sketchybar to macOS-only packages, added macOS Defaults section

## Testing Commands

```bash
# Test macOS defaults script
~/.macos

# Reload SketchyBar
sketchybar --reload

# Query bar state
sketchybar --query bar
sketchybar --query bar | jq '.hidden, .position'

# Reload AeroSpace
aerospace reload-config

# Toggle bar manually
~/.config/karabiner/scripts/toggle-sketchybar.sh

# Check workspace highlighting
aerospace list-workspaces --all
sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=1

# Restart Karabiner (needed after script changes)
killall Karabiner-Elements && open -a "Karabiner-Elements"
```

## Ready to Stow

Once satisfied with the configuration:
```bash
stow macos
stow sketchybar
stow aerospace
stow karabiner
stow scripts  # if not already stowed
```

## Future Improvements

Consider:
- Weather widget (requires custom plugin, not alias)
- Network status indicator (Wi-Fi name, connection status)
- System resource monitors (CPU, RAM usage)
- Music/media controls (requires custom plugin for Spotify/Music)
- Notification indicators
- VPN status indicator (Tailscale)
