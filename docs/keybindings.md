# Keybinding layers (macOS / phyrexia)

Who owns which modifier, which chords are reserved, and how to check for
collisions. Linux (Hyprland) has its own layer map in `docs/hyprland.md`.

## Principle

- **Cmd** belongs to the OS and the window manager (Aerospace). Apps see Cmd
  only for chords Aerospace does not claim.
- **Ctrl** belongs to the terminal stack: tmux, Pi, nvim, readline. No
  system-wide Ctrl chord may be enabled, because macOS intercepts symbolic
  hotkeys before the app sees the key.
- **Alt** is TUI word navigation (`macos-option-as-alt` in Ghostty/kitty).
- Outside terminals, Karabiner translates a fixed set of Ctrl chords to Cmd
  so Linux editing habits keep working in browsers and Slack.

## Layers, outermost first

A keypress is claimed by the first layer that binds it.

| Layer | Config | Scope | Owns |
|---|---|---|---|
| Kinesis Adv360 firmware | `keyboard/qwerty*.txt` (reference copy; live layout is on the keyboard's v-drive) | hardware | thumbs -> Cmd/Ctrl/Alt/Shift/Esc, `caps` -> Tab, home-row tap-hold mods (`a s d f` / `j k l ;` = Cmd Alt Ctrl Shift), `hk3` -> PrintScreen (macOS sees F13) |
| Karabiner simple mods | `karabiner/.config/karabiner/karabiner.json` | global | `caps_lock` -> Ctrl (laptop keyboard only; the Kinesis already sends Tab) |
| macOS symbolic hotkeys | `macos/.macos` (`symbolicHotkey` block) | global | Spotlight `cmd+d`; screenshots `shift+f13` / `ctrl+shift+f13`; `alt+cmd+d` Dock toggle. Disabled: `ctrl+space` input source, `ctrl+left/right` Spaces, `alt+cmd+d` Spotlight Finder, `cmd+shift+3/4/5` |
| Karabiner complex mods | same file; importable copies in `assets/complex_modifications/` | per app | outside terminals/Zed: `ctrl+{c,v,x,a,f,z,y,t,w,n,r}` -> Cmd; inside terminals: `ctrl+shift+c/v` -> `cmd+c/v`; `cmd+esc` SketchyBar toggle; `cmd+f` in System Settings |
| Aerospace | `aerospace/.config/aerospace/aerospace.toml` | global | `cmd+h/j/k/l` focus, `cmd+shift+h/j/k/l` move, `cmd+1..0` workspace, `cmd+shift+1..0` move to workspace, `cmd+space` float toggle, `cmd+shift+f` fullscreen |
| Ghostty global | `ghostty/.config/ghostty/config` | global | `cmd+shift+enter` new window (single instance) |
| Ghostty local | same | terminal | Ghostty defaults minus what Aerospace claims (`cmd+1..9` tabs are dead by design) |
| tmux | `tmux/.config/tmux/tmux.conf` + tmux-pain-control | terminal | prefix `C-a`; `prefix + h/j/k/l` panes, `prefix + \| -` splits, `prefix + .` swap window. **No root-table Ctrl bindings** (vim-tmux-navigator's tmux half was removed on purpose) |
| Pi | `pi/.pi/agent/keybindings.json` + defaults | terminal | `ctrl+shift+n/r/t/f/s` sessions, `ctrl+p/n` history, `ctrl+.` model cycle, plus the readline-style editor defaults |
| nvim | `nvim/.config/nvim/lua/core/editor.lua` | terminal | `C-h/j/k/l` cross pane edges into tmux (nvim side of vim-tmux-navigator calls `tmux select-pane`) |

Zed is excluded from the Karabiner Ctrl->Cmd rules like a terminal (vim mode
and its integrated terminal need raw Ctrl).

## Chords deliberately given up

- `cmd+1..9` in browsers, Slack, Ghostty: Aerospace workspaces.
- `cmd+h` Hide: Aerospace focus left.
- `cmd+space` Spotlight: Aerospace float toggle; Spotlight moved to `cmd+d`.
- `cmd+d` split (Ghostty), select-next (Zed): Spotlight.
- `cmd+enter` toggle fullscreen (Ghostty default): unbound, the global chord
  carries Shift so `cmd+enter` stays "submit" in Linear/GitHub/Gmail/Chrome.
- `ctrl+d/p/s` -> Cmd outside terminals: dropped on purpose (Spotlight,
  Print, Save Page dialogs on a stray press).
- bare `C-l` / `C-k` navigation from shell panes in tmux: use the prefix.

## Quick reference

`docs/keybindings-card.md` is the one-screen version of this file: the
chords you actually press, grouped by layer. `keys` (in `scripts/`) renders
it with bat; tmux `prefix + ?` opens it in a popup; `keys <pattern>` greps
it; `keys -e` edits it. Pi's `/cheat` ends with a short "Around pi" section
that points here. When a chord changes, update the card and the table above
together.

## Auditing

`~/.scripts/keybind-audit.sh` (in `scripts/`) collects chords from the live
symbolic hotkeys, Karabiner, Aerospace, Ghostty, live tmux root table and Pi
(defaults + overrides), normalizes them, and prints chords shared between
layers. Exit 1 on a collision with a global layer. `--all` dumps the table.
It compares our own layers only; it cannot know what a web app binds, so
new `global:` or Aerospace chords still need a moment's thought.

Symbolic hotkey changes written by `.macos` apply at next login on macOS 26
(`activateSettings` is gone). Decode a plist entry with the audit script's
tables: `parameters = [ascii, keycode, modifier mask]`, masks `0x20000`
shift, `0x40000` ctrl, `0x80000` alt, `0x100000` cmd, `0x800000` fn.

## Adding a binding

1. Pick the modifier by owner: Cmd for OS/WM, Ctrl for terminal-stack apps.
2. Global chords (Aerospace, Ghostty `global:`, symbolic hotkeys) must not
   be common app shortcuts; check `cmd+enter`, `cmd+k`, `cmd+/`, `cmd+,`
   style chords against the apps you live in.
3. Run the audit. Commit the config and, for system hotkeys, the `.macos`
   line together.
