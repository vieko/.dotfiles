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

local TERMINAL = "com.superlogical.terminal"
local SHELL = "com.superlogical.terminal.shell"

-- Bindings ------------------------------------------------------------------

-- Each binding spells out its full key, so `rex keymap` names the line that
-- made it and a grep for "ctrl+a>x" finds it. Loops cover key families.

-- Prefix twice sends a literal Ctrl+A (readline line start, nested tmux).
rex.bind("ctrl+a>ctrl+a", "pane.send_key", { key = "ctrl+a" })

-- Tabs (tmux windows)
rex.bind("ctrl+a>c", "client.tab.new")
rex.bind("ctrl+a>n", "client.tab.next")
rex.bind("ctrl+a>p", "client.tab.previous")
rex.bind("ctrl+a>ctrl+n", "client.tab.next")
rex.bind("ctrl+a>ctrl+p", "client.tab.previous")
rex.bind("ctrl+a>shift+,", "client.tab.move", { direction = "backward" }) -- <
rex.bind("ctrl+a>shift+.", "client.tab.move", { direction = "forward" }) -- >
rex.bind("ctrl+a>,", "client.tab.rename")
rex.bind("ctrl+a>shift+7", "client.tab.close") -- &
for i = 1, 9 do
  rex.bind("ctrl+a>" .. i, "client.tab.goto", { index = i })
end
rex.bind("ctrl+a>0", "client.tab.goto", { index = -1 })

-- Sessions
rex.bind("ctrl+a>s", "session.switch")
rex.bind("ctrl+a>w", "session.switch")
rex.bind("ctrl+a>shift+4", "session.rename") -- $
rex.bind("ctrl+a>shift+9", "session.previous") -- (
rex.bind("ctrl+a>shift+0", "session.next") -- )

-- Panes: focus (pain-control binds both h and C-h)
for key, dir in pairs({ h = "left", j = "down", k = "up", l = "right" }) do
  rex.bind("ctrl+a>" .. key, "pane.focus", { direction = dir, wrap = false })
  rex.bind("ctrl+a>ctrl+" .. key, "pane.focus", { direction = dir, wrap = false })
end
rex.bind("ctrl+a>o", "pane.focus_next")
rex.bind("ctrl+a>;", "pane.focus_previous")

-- Panes: split. Rex's split has no "full width"; split_full below does it.
rex.bind("ctrl+a>shift+\\", "pane.split", { direction = "right" }) -- |
rex.bind("ctrl+a>-", "pane.split", { direction = "down" })
rex.bind("ctrl+a>shift+5", "pane.split", { direction = "right" }) -- %
rex.bind("ctrl+a>shift+'", "pane.split", { direction = "down" }) -- "
rex.bind("ctrl+a>\\", "split_full", { direction = "right" })
rex.bind("ctrl+a>shift+-", "split_full", { direction = "down" }) -- _

-- Panes: resize one step, or enter resize mode for repeats (tmux -r).
for key, dir in pairs({ h = "left", j = "down", k = "up", l = "right" }) do
  rex.bind("ctrl+a>shift+" .. key, "pane.resize", { direction = dir })
end
rex.bind("ctrl+a>r", "client.mode.enter", { name = "resize" })
rex.bind("ctrl+a>=", "pane.balance")

-- Panes: other
rex.bind("ctrl+a>z", "pane.zoom")
rex.bind("ctrl+a>x", "pane.close")
rex.bind("ctrl+a>shift+1", "pane.move_to_new_tab") -- !
rex.bind("ctrl+a>f", "pane.float")
rex.bind("ctrl+a>shift+y", "copy_cwd") -- Y (tmux-yank)

-- Find, palette, help
rex.bind("ctrl+a>[", "client.find.open")
rex.bind("ctrl+a>shift+;", "client.palette.toggle") -- :
rex.bind("ctrl+a>shift+/", "keys_card") -- ?

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
