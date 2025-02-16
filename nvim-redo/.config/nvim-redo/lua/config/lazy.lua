-- [[ LAZY ]]
local M = {}

---@param name "autocmds" | "keymaps" | "options"
function M.load(name)
  local function _load(mod)
    if require("lazy.core.cache").find(mod)[1] then
      require(mod)
    end
  end

  _load("config." .. name)

  local pattern = "Arcana" .. name:sub(1, 1):upper() .. name:sub(2)
  vim.api.nvim_exec_autocmds("User", { pattern = pattern, modeline = false })
end

---@param colorscheme string
function M.setup(colorscheme)
  local lazy_autocmds = vim.fn.argc(-1) == 0
  if not lazy_autocmds then
    M.load("autocmds")
  end

  local group = vim.api.nvim_create_augroup("Arcana", { clear = true })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "VeryLazy",
    callback = function()
      if lazy_autocmds then
        M.load("autocmds")
      end
      M.load("keymaps")
    end,
  })

  if colorscheme == "" then
    return
  end
  vim.o.termguicolors = true
  vim.g.tinted_colorspace = 256
  vim.g.tinted_background_transparent = 1
  vim.cmd.colorscheme(colorscheme)
end

return M
