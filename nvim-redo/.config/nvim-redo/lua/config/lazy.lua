-- [[ BOOTSTRAP ]]
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

local spec = {
  { import = "plugins.colorscheme" },
  { import = "plugins.vim-tmux-navigator" },
  { import = "plugins.better-escape" },
  { import = "plugins.vim-sleuth" },
  { import = "plugins.git-signs" },
  { import = "plugins.lsp" },
  { import = "plugins.cmp" },
  { import = "plugins.conform" },
  { import = "plugins.treesitter" },
  { import = "plugins.snacks" },
  { import = "plugins.nvim-lint" },
  { import = "plugins.mini" },
  { import = "plugins.surround" },
  { import = "plugins.autopairs" },
  { import = "plugins.supermaven" },
}

require("config.options")
require("config.autocmds")
require("config.keymaps")

require("lazy").setup({
  spec = spec,
  checker = { enabled = true },
  change_detection = { notify = false },
  ui = {
    border = "rounded",
    icons = {
      cmd = " ",
      config = "",
      event = "⚡ ",
      ft = " ",
      init = " ",
      import = " ",
      keys = " ",
      lazy = "󰒲 ",
      loaded = "",
      not_loaded = "",
      plugin = " ",
      runtime = " ",
      require = " ",
      source = " ",
      start = " ",
      task = " ",
      list = {
        "",
        "",
        "",
        "",
      },
    },
  },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
