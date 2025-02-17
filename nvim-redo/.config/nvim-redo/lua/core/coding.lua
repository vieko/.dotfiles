-- [[ CODING ]]
return {
  { -- Autocompletion
    "hrsh7th/nvim-cmp",
    version = false,
    event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
    },
    config = function()
      local cmp = require("cmp")
      local defaults = require("cmp.config.default")()
      cmp.setup({
        completion = { completeopt = "menu,menuone,noinsert" },
        mapping = cmp.mapping.preset.insert({
          ["<C-n>"] = cmp.mapping.select_next_item(),
          ["<C-p>"] = cmp.mapping.select_prev_item(),
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<Tab>"] = cmp.mapping.confirm({ select = true }),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
        }),

        sources = cmp.config.sources({
          { name = "lazydev" },
          { name = "nvim_lsp" },
          { name = "path" },
        }, { name = "buffer" }),
        ---@diagnostic disable-next-line: missing-fields
        formatting = {
          format = function(_, item)
            local widths = {
              abbr = vim.g.cmp_widths and vim.g.cmp_widths.abbr or 40,
              menu = vim.g.cmp_widths and vim.g.cmp_widths.menu or 30,
            }

            for key, width in pairs(widths) do
              if item[key] and vim.fn.strdisplaywidth(item[key]) > width then
                item[key] = vim.fn.strcharpart(item[key], 0, width - 1) .. "…"
              end
            end

            return item
          end,
        },
        sorting = defaults.sorting,
      })
    end,
  },
  { -- supermaven
    "supermaven-inc/supermaven-nvim",
    event = "InsertEnter",
    lazy = false,
    config = function()
      local sm = require("supermaven-nvim")
      sm.setup({
        keymaps = {
          accept_suggestion = "<C-l>",
        },
        disable_inline_completion = false,
        ignore_filetypes = { "bigfile", "snacks_input", "snacks_notif" },
      })
    end,
  },
  { -- copilot
    "github/copilot.vim",
    enabled = false,
    config = function()
      vim.g.copilot_workspace_folders = { "~/Documents/Development", "~/Documents/Sandbox", "~/dev", "~/tmp" }
      vim.g.copilot_assume_mapped = true
      vim.g.copilot_no_tab_map = true
      vim.g.copilot_filetypes = {
        ["TelescopePrompt"] = false,
      }
      vim.keymap.set("i", "<C-l>", 'copilot#Accept("\\<CR>")', { expr = true, replace_keycodes = false })
    end,
  },
  { -- install lsp servers
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        "stylua",
        "prettier",
        "prettierd",
        "codespell",
        "misspell",
        "cspell",
        "markdownlint",
        "rustywind",
      },
    },
  },
  { -- Auto pairs
    "echasnovski/mini.pairs",
    event = "VeryLazy",
    opts = {
      modes = { insert = true, command = true, terminal = false },
      skip_next = [=[[%w%%%'%[%"%.%`%$]]=],
      skip_ts = { "string" },
      skip_unbalanced = true,
      markdown = true,
    },
  },
  { -- Code comment
    "folke/ts-comments.nvim",
    event = "VeryLazy",
    opts = {},
  },
}
