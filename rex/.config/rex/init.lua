-- Rex config (macOS / phyrexia). Ports the tmux layer: prefix Ctrl+A, then
-- the tmux-pain-control and tmux-sensible keys we use. See
-- docs/rex-assessment.md and docs/keybindings-card.md.
--
-- Cmd chords stay with the OS and Aerospace, bare Ctrl chords stay with the
-- program in the pane; Rex gets Ctrl+A sequences only. Apply with
-- `rex config reload`; check with `rex config check` and `rex keymap`.
--
-- Not ported: tmux `[` copy mode (Rex has none yet; `[` opens Find),
-- `a` last window (Rex tracks no window history), `.` swap with index,
-- `d` detach, resurrect `C-s` / `C-r` (Rex restores layouts itself).

local P = "ctrl+a>"
local TERMINAL = "com.superlogical.terminal"
local SHELL = "com.superlogical.terminal.shell"

-- Bindings ------------------------------------------------------------------

local function bind(keys, action, args)
  rex.bind(P .. keys, action, args)
end

-- Prefix twice sends a literal Ctrl+A (readline line start, nested tmux).
bind("ctrl+a", "pane.send_key", { key = "ctrl+a" })

-- Tabs (tmux windows)
bind("c", "client.tab.new")
bind("n", "client.tab.next")
bind("p", "client.tab.previous")
bind("ctrl+n", "client.tab.next")
bind("ctrl+p", "client.tab.previous")
bind("shift+,", "client.tab.move", { direction = "backward" }) -- <
bind("shift+.", "client.tab.move", { direction = "forward" }) -- >
bind(",", "client.tab.rename")
bind("shift+7", "client.tab.close") -- &
for i = 1, 9 do
  bind(tostring(i), "client.tab.goto", { index = i })
end
bind("0", "client.tab.goto", { index = -1 })

-- Sessions
bind("s", "session.switch")
bind("w", "session.switch")
bind("shift+4", "session.rename") -- $
bind("shift+9", "session.previous") -- (
bind("shift+0", "session.next") -- )

-- Panes: focus (pain-control binds both h and C-h)
for key, dir in pairs({ h = "left", j = "down", k = "up", l = "right" }) do
  bind(key, "pane.focus", { direction = dir, wrap = false })
  bind("ctrl+" .. key, "pane.focus", { direction = dir, wrap = false })
end
bind("o", "pane.focus_next")
bind(";", "pane.focus_previous")

-- Panes: split. Rex's split has no "full width"; split_full below does it.
bind("shift+\\", "pane.split", { direction = "right" }) -- |
bind("-", "pane.split", { direction = "down" })
bind("shift+5", "pane.split", { direction = "right" }) -- %
bind("shift+'", "pane.split", { direction = "down" }) -- "
bind("\\", "split_full", { direction = "right" })
bind("shift+-", "split_full", { direction = "down" }) -- _

-- Panes: resize one step, or enter resize mode for repeats (tmux -r).
for key, dir in pairs({ h = "left", j = "down", k = "up", l = "right" }) do
  bind("shift+" .. key, "pane.resize", { direction = dir })
end
bind("r", "client.mode.enter", { name = "resize" })
bind("=", "pane.balance")

-- Panes: other
bind("z", "pane.zoom")
bind("x", "pane.close")
bind("shift+1", "pane.move_to_new_tab") -- !
bind("f", "pane.float")
bind("shift+y", "copy_cwd") -- Y (tmux-yank)

-- Find, palette, help
bind("[", "client.find.open")
bind("shift+;", "client.palette.toggle") -- :
bind("shift+/", "keys_card") -- ?

-- Resize mode: hjkl in 5% steps, HJKL in 15%, Escape or Enter leaves.
rex.mode("resize", { exclusive = true })
for key, dir in pairs({ h = "left", j = "down", k = "up", l = "right" }) do
  rex.bind("resize/" .. key, "pane.resize", { direction = dir })
  rex.bind("resize/shift+" .. key, "pane.resize", { direction = dir, amount = 15 })
end
rex.bind("resize/=", "pane.balance")
rex.bind("resize/enter", "client.mode.exit")

-- Actions -------------------------------------------------------------------

local function check(result, err)
  if err ~= nil then error(err, 0) end
  return result
end

-- The focused pane's directory, from the OSC 7 that bash/.bashrc sends.
local function pane_dir(block_id)
  local r = rex.block.call(TERMINAL, "pwd", { block_id = block_id })
  local url = r and r.pwd
  if not url then return nil end
  local path = url:gsub("^file://[^/]*", "")
  return (path:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

local function active_tiled_root(ctx)
  local view = check(rex.session.view{})
  for _, w in ipairs(view.windows or {}) do
    if w.window_id == view.active_window_id then
      for _, layer in ipairs(w.layers or {}) do
        if layer.kind == "tiled" then
          local root = layer.layout
          return (root.split and root.split.split_id) or root.block_id
        end
      end
    end
  end
  error("no tiled layer in the active window", 0)
end

rex.action{
  name = "split_full",
  title = "Split Full Width or Height",
  description = "Split the whole tab, not just the focused pane (tmux split-window -f).",
  args = { direction = "string" },
  run = function(ctx, args)
    local horizontal = args.direction == "right" or args.direction == "left"
    local before = args.direction == "left" or args.direction == "up"
    check(rex.session.new_split{
      anchor_id = active_tiled_root(ctx),
      direction = horizontal and "horizontal" or "vertical",
      side = before and "before" or "after",
      focus = true,
      layout = { block = { flavor = SHELL, options = { cwd = pane_dir(ctx.block_id) } } },
    })
  end,
}

rex.action{
  name = "copy_cwd",
  title = "Copy Pane Directory",
  run = function(ctx)
    local dir = pane_dir(ctx.block_id)
    if not dir then error("this pane has not reported a directory", 0) end
    local r = check(rex.exec({ "/usr/bin/pbcopy" }, { stdin = dir }))
    if not r.ok then error(r.stderr, 0) end
  end,
}

rex.action{
  name = "keys_card",
  title = "Show Keybinding Card",
  description = "docs/keybindings-card.md in a floating pane (tmux prefix + ?).",
  keywords = "keys shortcuts help",
  run = function(ctx)
    local view = check(rex.session.view{})
    check(rex.session.new_layer{
      window_id = view.active_window_id,
      bounds = { 0.05, 0.05, 0.9, 0.9 },
      focus = true,
      layout = { block = { flavor = SHELL, options = {
        command = { os.getenv("HOME") .. "/.scripts/keys" },
      } } },
    })
  end,
}
