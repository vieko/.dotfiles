-- [[ KEYMAPS ]]
local M = {}

local function map(mode, lhs, rhs, opts)
  local options = { noremap = true, silent = true }
  if opts then
    options = vim.tbl_extend("force", options, opts)
  end
  vim.keymap.set(mode, lhs, rhs, options)
end

local function disable_arrows()
  local arrows = { "<up>", "<down>", "<left>", "<right>" }
  for _, arrow in ipairs(arrows) do
    map("n", arrow, "", { desc = "Disabled arrow key" })
    map("i", arrow, "", { desc = "Disabled arrow key" })
  end
end

local function setup_buffer_operations()
  -- buffer navigation
  map("n", "gT", "<cmd>bprevious<cr>", { desc = "Prev Buffer" })
  map("n", "gt", "<cmd>bnext<cr>", { desc = "Next Buffer" })

  -- move lines up and down in visual mode
  map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selected lines down" })
  map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selected lines up" })
end

local function setup_navigation_maps()
  -- move through wrapped lines when no count is given
  map({ "n", "x" }, "j", [[v:count ? 'j' : 'gj']], { expr = true, desc = "Move down (including wrapped lines)" })
  map({ "n", "x" }, "k", [[v:count ? 'k' : 'gk']], { expr = true, desc = "Move up (including wrapped lines)" })

  -- half page up and down keeping the cursor centered
  local centered_movements = {
    { key = "<C-u>", desc = "Half page up" },
    { key = "<C-d>", desc = "Half page down" },
    { key = "<C-o>", desc = "Jump back" },
    { key = "<C-i>", desc = "Jump forward" },
  }
  for _, movement in ipairs(centered_movements) do
    map("n", movement.key, movement.key .. "zz", { desc = movement.desc })
  end

  -- move to the beginning and end of line
  -- map({ "n", "v", "o" }, "gl", "$", { desc = "Go to end of line" })
  -- map({ "n", "v", "o" }, "gh", "^", { desc = "Go to start of line" })
end

local function setup_quality_of_life_tweaks()
  -- set highlight on search, but clear on pressing <esc> in normal and insert modes
  map({ "i", "n" }, "<Esc>", "<cmd>noh<CR><Esc>", { desc = "Escape and clear search" })

  -- prevent capital Q from clobbering the current buffer
  map("n", "Q", "<Nop>", { desc = "Prevent Ex Mode when pressing Q" })

  -- search terms stay in the middle of the screen
  map("n", "n", "nzzzv", { desc = "Next search result (centered)" })
  map("n", "N", "Nzzzv", { desc = "Previous search result (centered)" })

  -- Preserve visual selection while indenting
  map("v", "<", "<gv", { desc = "Indent left and maintain selection" })
  map("v", ">", ">gv", { desc = "Indent right and maintain selection" })
end

local function setup_diagnostics()
  local diagnostic_goto = function(next, severity)
    local go = next and vim.diagnostic.goto_next or vim.diagnostic.goto_prev
    severity = severity and vim.diagnostic.severity[severity] or nil
    return function()
      go({ severity = severity, float = false })
    end
  end
  map("n", "]d", diagnostic_goto(true), { desc = "Go to next diagnostic" })
  map("n", "[d", diagnostic_goto(false), { desc = "Go to previous diagnostic" })
  map("n", "g]", diagnostic_goto(true), { desc = "Go to next diagnostic" })
  map("n", "g[", diagnostic_goto(false), { desc = "Go to previous diagnostic" })
  -- map("n", "gh", vim.diagnostic.open_float, { desc = "Line diagnostics" })
end

--- Setup all keymaps
function M.setup()
  disable_arrows()
  setup_buffer_operations()
  setup_navigation_maps()
  setup_quality_of_life_tweaks()
  setup_diagnostics()
end

return M.setup()
