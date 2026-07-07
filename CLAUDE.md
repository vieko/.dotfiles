# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Session Context

Read `<project>/.bonfire/index.md` for current state. The file is kept current
automatically by host-native bonfire adapters — no commands to run.

- **Pi**: extension loaded via symlink at `~/.pi/agent/extensions/bonfire-dev`
  pointing to `~/dev/bonfire/pi`. Hooks `session_compact` + `session_shutdown`.
- **Claude Code**: Stop hook in `~/.claude/settings.json` pointing to
  `~/dev/bonfire/claude/update-bonfire.mjs`.
- **Other agents (Codex, OpenCode, …)**: fallback skill via
  `/skill:bonfire end` only, has `disable-model-invocation: true`.

Opt in per repo with `mkdir <repo>/.bonfire`. Without that directory, all
adapters and the skill no-op silently.

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

**Cross-platform packages:** bash, git, kitty, ghostty, tmux, nvim, starship, bat, btop, lazygit, yazi, assets, claude, pi, agents, slack
**macOS-only:** macos, macos-keyboard, aerospace, sketchybar
**Linux-only:** hypr, waybar, dunst, fuzzel, mako, rofi, sway, i3, polybar

### Agent-related Packages

**`pi/`** — Pi coding agent config. Stows to `~/.pi/agent/`. Tracks: `AGENTS.md`,
`settings.json`, `models.json`, `keybindings.json`, `prompts/`, `themes/`. **Does NOT
track** `auth.json`, `sessions/`, or `skills/` (auto-generated / machine-local).

`models.json` registers custom models (or models newer than Pi's built-in registry)
for the configured providers. See `docs/models.md` in the pi package. Merges into
built-in providers — most useful for adding bleeding-edge gateway models that
Pi's bundled registry doesn't know about yet.

Note: Pi writes `lastChangelogVersion` into `settings.json` on update. Expect
occasional churn in git status; commit when convenient.

**`agents/`** — cross-agent shared skills. Stows to `~/.agents/`. Single source
of truth for skills that any agent (Pi, Claude, Codex) should see.

Some skills are symlinks to dev repos:
- `~/.agents/skills/bonfire` → `~/dev/bonfire/skills/bonfire`
- `~/.agents/skills/anvil` → `~/dev/anvil/packages/cli/skills/anvil`

On a fresh machine, those dev repos must be cloned (`~/dev/bonfire`, `~/dev/anvil`)
before the symlinks resolve. Other skills are self-contained directories.

(`anvil` is the successor to the now-frozen `forge`; the old
`~/dev/forge/skills/forge` symlink is gone.)

**Bonfire adapter installation:**

The Pi adapter is tracked as a `pi install` package entry in
`pi/.pi/agent/settings.json` (`packages: ["git:github.com/vieko/bonfire@vX.Y.Z"]`).
On a fresh machine, run `pi update` after stowing to materialize it. Pi
clones to `~/.pi/agent/git/github.com/vieko/bonfire/` and the root
`package.json` manifest points at `./pi/extension.ts`.

The Claude Code adapter is wired via a `Stop` hook entry in
`claude/.claude/settings.json` pointing to
`/Users/vieko/dev/bonfire/claude/update-bonfire.mjs`. This requires
`~/dev/bonfire/` cloned (see the deploy checklist) and the absolute path
tracked in dotfiles — update it if your home dir layout differs on Linux.

**Skill layout convention:**

- **Tracked skills** live as real directories under `agents/.agents/skills/<name>/`
  in this repo. They ship via stow with the rest of the dotfiles. Use this for
  stable, machine-agnostic skills that don't change often.
- **Symlinked skills** live at `~/dev/<name>/skills/<name>/` and are symlinked
  in from `agents/.agents/skills/<name>`. Use this for skills under active
  development that benefit from their own git history, releases, and PRs.

Both resolve to the same path at runtime (`~/.agents/skills/<name>`). The
choice is purely about where the source of truth lives. Migrate a skill
between modes by replacing the dotfiles entry with the opposite kind
(symlink → directory or vice versa) and re-stowing `agents/`.

**Spinner verb dictionary (shared across agents):**

The occult/metallurgical agent-spinner verbs are centralized in one
canonical file: `agents/.agents/verbs.json` (structured by section).
Two consumers read it:

- **Pi** — `pi/.pi/agent/extensions/spinner-verbs.ts` reads
  `~/.agents/verbs.json` at runtime. Always current; nothing to regenerate.
- **Claude Code** — `claude/.claude/settings.json` `spinnerVerbs.verbs`
  (flat array, lives in dotfiles, synced).

(forge was a third consumer via `~/dev/forge/src/display.ts`; it's frozen and
that file is gone. anvil, its successor, does not consume the shared verbs.)

Claude's synced copy is regenerated from the canonical JSON by
`agents/.agents/scripts/sync-verbs.mjs`. Both the canonical file and the synced
copy now live in this repo, but there is intentionally **no** commit hook
enforcing sync — it's a manual discipline:

```bash
# 1. edit the canonical dictionary
$EDITOR agents/.agents/verbs.json

# 2. regenerate the synced copy
node agents/.agents/scripts/sync-verbs.mjs

# 3. (optional) confirm no drift remains
node agents/.agents/scripts/sync-verbs.mjs --check   # exit 1 on drift

# 4. commit dotfiles: verbs.json + claude/settings.json together
```

**`claude/`** — Claude Code config. Stows to `~/.claude/`. Tracks `settings.json`
and `statusline.sh` only — matches the same "config not state" philosophy as `pi/`.

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

On Fedora: COPR `lionheartp/Hyprland` (see `scripts/.scripts/fedora-fresh-install.sh`). Install hy3 via `hyprpm`; its version must match hyprland's.

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
