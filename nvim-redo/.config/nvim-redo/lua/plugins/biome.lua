local Lsp = require("utils.lsp")

return {
  {
    "williamboman/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "biome" })
    end,
  },
  {
    "neovim/nvim-lspconfig",
    ---@class PluginLspOpts
    opts = {
      servers = {
        biome = {
          root_dir = function()
            if Lsp.biome_config_exists() then
              return Lsp.biome_config_path()
            end
            return vim.fn.stdpath("config")
          end,
        },
      },
    },
  },
}
