# Repository Guide for Agents

Canonical guidance for any coding agent (Claude Code, Pi, Codex, ...) working in
this repository. `CLAUDE.md` is a symlink to this file, so both filenames
resolve to identical content; edit only `AGENTS.md`.

## Session Context

Read `.bonfire/index.md` for current state. Host-native bonfire adapters keep
it current; there are no commands to run. Pi loads the adapter from the
`packages` pin in `pi/.pi/agent/settings.base.json` (PHYREXIA swaps the pin for
`~/dev/bonfire` via `hosts/packages.phyrexia.json`); Claude Code runs it from
a `Stop` hook in `claude/.claude/settings.json`; other agents use
`/skill:bonfire end` explicitly. Install detail: `docs/agent-packages.md`.

## Dotfiles Management

### Commands

- `stow <folder>`: symlink one configuration package (preferred method)
- `stow -t / <folder>`: symlink system-wide configurations (may need sudo)
- `git add -u` / `git add <file>`: stage changes as usual

**Note:** Stow packages individually based on OS. Do NOT run `stow .` blindly.

### Cross-Platform Strategy

Primary packages by platform. The repo also holds many smaller single-purpose
packages not listed here (e.g. `aws`, `gh`, `gnupg`, `cargo`, `zed`, `picom`,
`tofi`, GTK/Qt theming); stow what you need.

**Cross-platform packages:** bash, git, kitty, ghostty, tmux, nvim, starship, bat, btop, lazygit, yazi, assets, claude, pi, opencode, agents, slack
**macOS-only:** macos, macos-keyboard, aerospace, sketchybar, karabiner, rex (trial; see `docs/rex-assessment.md`)
**Linux-only:** hypr, waybar, dunst, fuzzel, mako, rofi, sway, i3, polybar, ptyxis (run `ptyxis/setup-ptyxis.sh` once after stowing)

### Agent-related Packages

Rules that apply on every edit. Layout, rationale, and bootstrap steps are in
`docs/agent-packages.md`; read it before changing any of these packages.

- **`pi/`** tracks `AGENTS.md`, `settings.base.json`, `hosts/*.json`,
  `setup-pi.sh`, `models.json`, `keybindings.json`, `prompts/`, `themes/`,
  `extensions/`, `prose/`. It does not track `auth.json`, `sessions/`,
  `models-store.json`, or the generated `settings.json`. Never edit
  `~/.pi/agent/settings.json` by hand: change `settings.base.json` or a
  `hosts/*.json` fragment, then run `pi/.pi/agent/setup-pi.sh`.
- **`agents/`** stows to `~/.agents/` and is the single source of truth for
  cross-agent skills. `bonfire` and `anvil` are gitignored symlinks into
  `~/dev`; regenerate them with `agents/.agents/setup-skill-symlinks.sh`.
  After editing `agents/.agents/verbs.json`, run
  `node agents/.agents/scripts/sync-verbs.mjs` and commit
  `claude/.claude/settings.json` with it.
- **`claude/`** tracks Claude Code `settings.json`, `statusline.sh`, and
  `output-styles/` (kept in sync with pi-prose by hand).
- **`opencode/`** is a bounded trial, not a Summoner runtime. Keep it as
  maintained config unless it earns a standing weekly role.

### OS Detection Pattern

`USER_OS` (`macos` or `linux`) is exported in `bash/.bash_exports`. In bash,
branch on `$OSTYPE` (`linux-gnu*` / `darwin*`) when a config has no env
interpolation.

### OS-Specific Configs & macOS Defaults

Details live in `docs/os-configs.md` (git GPG setup script, kitty/ghostty
`os-current`/`config-current` symlink pattern, clipboard rules),
`docs/macos.md` (defaults script), and `docs/keybindings.md` (which layer
owns which modifier, plus `scripts/.scripts/keybind-audit.sh`). Read them
when bootstrapping a fresh machine, switching OS, or touching the
kitty/ghostty/macos/aerospace/karabiner/tmux packages or any keybinding.
Inline gotcha: never hardcode clipboard commands in nvim/tmux configs; both
auto-detect the OS tool.

### Style Guidelines

- **Organization**: each application's configs belong in their own directory
- **Naming**: lowercase directories, original case for config files
- **Comments**: brief comments for non-obvious configurations
- **Platform**: distinguish Linux-specific from cross-platform configs
- **Consistency**: consistent theming across applications
- **Scripts**: camelCase variables; executables live in `scripts/`

## Hyprland Configuration

Full guide in `docs/hyprland.md` (hy3 via hyprpm, modular config, host
detection via `hypr/.config/hypr/scripts/host.sh`, key scripts). Read it
before touching `hypr/`. Quick refs: `hyprctl reload`, `hyprctl monitors`,
`hyprctl clients`.
