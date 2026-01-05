# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Session Context

Read `.bonfire/index.md` for current project state, recent work, and priorities.

**Bonfire Commands:**
- `/bonfire:start` - Start a session (reads context)
- `/bonfire:end` - End session (updates context)
- `/bonfire:spec` - Create implementation spec
- `/bonfire:document` - Document a topic
- `/bonfire:review` - Review work for blindspots
- `/bonfire:archive` - Archive completed work
- `/bonfire:configure` - Change project settings

## Dotfiles Management

### Commands

- `stow <folder>`: Symlink specific configuration folder (preferred method)
- `stow -t / <folder>`: Symlink system-wide configurations (may need sudo)
- `git status`: Check status of dotfiles repository
- `git diff`: View pending changes
- `git add -u`: Add modified tracked files
- `git add <file>`: Add specific file

**Note:** Stow packages individually based on OS. Do NOT run `stow .` blindly.

### Cross-Platform Strategy

**Cross-platform packages:** bash, git, kitty, tmux, nvim, starship, bat, btop, lazygit, yazi, assets
**macOS-only:** macos, macos-keyboard, aerospace, sketchybar
**Linux-only:** hypr, waybar, dunst, fuzzel, mako, rofi, sway, i3, polybar

### OS Detection Pattern

A `USER_OS` environment variable is exported in `bash/.bash_exports`:

- `macos` on macOS
- `linux` on Linux

Use this in configs that support environment variables, or use conditional logic in bash:

```bash
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux-specific
elif [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS-specific
fi
```

### OS-Specific Setup Scripts

**Git GPG configuration** requires running a setup script when switching between operating systems:

```bash
~/.scripts/setup-git-gpg.sh
```

This script automatically detects the OS and updates the git `gpg.program` path to point to the correct location (`/Users/$USER` on macOS, `/home/$USER` on Linux).

**When to run:**
- After fresh stowing on a new system
- When switching between macOS and Linux
- If git commit signing fails with "gpg not found" errors

### OS-Specific Configuration Pattern

**Kitty terminal** uses a symlink-based approach:

1. Main config: `kitty.conf` (contains defaults)
2. OS-specific configs: `os-macos.conf`, `os-linux.conf`
3. Symlink: `os-current.conf` → points to the correct OS config
4. Run `./setup-os-link.sh` after stowing to create the symlink
5. Main config includes `os-current.conf` at the END (so it overrides defaults)

This pattern can be reused for other tools that don't support environment variables.

### Clipboard Configuration

**Neovim** clipboard integration:

- `clipboard = "unnamedplus"` in `nvim/lua/config/options.lua`
- Neovim auto-detects clipboard tool: `pbcopy/pbpaste` on macOS, `wl-copy` on Wayland, `xclip` on X11
- Do NOT hardcode clipboard commands in configs

**Tmux** clipboard integration:

- Uses `tmux-yank` plugin (auto-detects OS)
- Copy mode: `Space` to start selection, `y` to copy to system clipboard
- Integrates seamlessly with system clipboard on both macOS and Linux

### macOS Defaults Configuration

**Setup:**
1. Stow the assets package: `stow assets` (for wallpapers)
2. Stow the macOS package: `stow macos`
3. Run the configuration script: `~/.macos`
4. Enter password when prompted for system-level changes

**What it configures:**
- Computer name (set to "phyrexia") - commented out, requires sudo
- Dock permanently hidden (1000s delay, toggle with Option+Command+D)
- Menu bar autohides on hover (Ctrl-Fn-F2 to toggle)
- Keyboard repeat rate (fastest: KeyRepeat=1, InitialKeyRepeat=10, requires logout)
- Wallpaper (One Dark solid color from ~/Pictures/Wallpapers)
- Instant animations (dock toggle, window minimize/resize, Mission Control)
- Scale effect for minimize (faster than genie)
- Disabled dock launch animations

**Adding new settings:**
- Edit `macos/.macos` to add additional `defaults write` commands
- Group related settings under section headers for organization
- Test changes by running `~/.macos` again (safe to run multiple times)
- Based on [Mathias Bynens' dotfiles](https://github.com/mathiasbynens/dotfiles/blob/main/.macos)

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



## Sessions Pattern (Optional)

If you've set up the Sessions Directory Pattern (`npx create-sessions-dir`):

- `/start-session` - Read context, fetch GitHub/Linear issues
- `/end-session` - Update context, detect merged PRs, auto-archive
- `/plan` - Create structured implementation plans
- `/document` - Topic-specific documentation with sub-agents
- `/change-git-strategy` - Change git strategy for .sessions/

Learn more: https://vieko.dev/sessions

## External Tools (Optional)

**For GitHub integration:**
```bash
gh auth login    # Required for PR/issue fetching
```

**For Linear integration:**
Configure the Linear MCP server in your Claude settings.
See: https://github.com/anthropics/claude-code/blob/main/docs/mcp.md

Commands will gracefully handle missing tools and prompt for manual input.
