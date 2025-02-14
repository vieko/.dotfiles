-- [[ KEYMAPS ]]
local M = {}
local auto_format = true

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
end

local function setup_quality_of_life_tweaks()
  -- set highlight on search, but clear on pressing <esc> in normal and insert modes
  map({ "i", "n" }, "<Esc>", "<cmd>noh<CR><Esc>", { desc = "Escape and clear search" })

  -- search terms stay in the middle of the screen
  map("n", "n", "nzzzv", { desc = "Next search result (centered)" })
  map("n", "N", "Nzzzv", { desc = "Previous search result (centered)" })
end

local function setup_toggles()
  -- Toggle wrap
  map("n", "<c-k>z", function()
    vim.opt.wrap = not vim.opt.wrap:get()
    local status = vim.opt.wrap:get() and "enabled" or "disabled"
    vim.notify("Wrap " .. status, vim.log.levels.INFO)
  end, { desc = "Toggle Wrap" })
end

--- Setup all keymaps
function M.setup()
  disable_arrows()
  setup_buffer_operations()
  setup_quality_of_life_tweaks()
  setup_toggles()
end

return M.setup()
