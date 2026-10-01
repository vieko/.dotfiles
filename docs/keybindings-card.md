# Keys (macOS / phyrexia)

Cmd = OS and Aerospace. Ctrl = tmux, Pi, nvim, readline. Alt = word motion.
Full layer map and collision audit: `docs/keybindings.md`, `keybind-audit.sh`.

## Aerospace (Cmd)

- `Cmd+H/J/K/L`: focus pane. `Cmd+Shift+H/J/K/L`: move pane.
- `Cmd+1..9, 0`: workspace. `Cmd+Shift+1..9, 0`: send window to workspace.
- `Cmd+Space`: float / tile toggle. `Cmd+Shift+F`: fullscreen.
- `Cmd+Esc`: toggle SketchyBar (Karabiner).

## System

- `Cmd+D`: Spotlight. `Alt+Cmd+D`: Dock toggle.
- `Shift+F13`: screenshot to file. `Ctrl+Shift+F13`: selection to clipboard.
  (Kinesis `hk3` sends F13.)
- `Cmd+Shift+Enter`: new Ghostty window, from anywhere.
- Outside terminals and Zed: `Ctrl+{C,V,X,A,F,Z,Y,T,W,N,R}` act as Cmd.
- Inside terminals: `Ctrl+Shift+C/V` copy / paste.

## tmux (prefix `C-a`)

- `c` new window. `n` / `p` next / prev. `w` pick. `,` rename. `.` swap with index.
- `|` / `-` split. `\` / `_` full-width split.
- `h/j/k/l` focus pane. `H/J/K/L` resize. `<` / `>` swap pane. `z` zoom. `x` kill.
- `[` copy mode (vi; `v` select, `y` yank). `y` yank command line. `Y` yank cwd.
- `C-s` save session. `C-r` restore. `d` detach. `$` rename session.
- `?` this card. `:list-keys` the raw table.
- No bare Ctrl chords at the root: they belong to the app in the pane.

## Pi (Ctrl)

- `Ctrl+Shift+N/R/T/F`: new / resume / tree / fork. `Ctrl+Shift+S`: search.
- `Ctrl+P` / `Ctrl+N`: prompt history. `Ctrl+.`: cycle model. `Ctrl+L`: pick.
- `Ctrl+X`: copy last reply. `Ctrl+O`: expand tool output. `Ctrl+G`: edit in nvim.
- `Shift+Tab`: thinking level. `Alt+Enter`: queue follow-up. `/cheat`, `/hotkeys`.

## nvim

- `C-h/j/k/l`: cross pane edges into tmux (nvim side only).
