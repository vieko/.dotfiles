-- [[ EDITOR ]]
return {
  { -- detect tabstops and shiftwidth automatically
    "tpope/vim-sleuth",
  },
  {
    "christoomey/vim-tmux-navigator",
    cmd = {
      "TmuxNavigateLeft",
      "TmuxNavigateDown",
      "TmuxNavigateUp",
      "TmuxNavigateRight",
      "TmuxNavigatePrevious",
    },
    keys = {
      { "<c-h>", "<cmd><C-U>TmuxNavigateLeft<cr>" },
      { "<c-j>", "<cmd><C-U>TmuxNavigateDown<cr>" },
      { "<c-k>", "<cmd><C-U>TmuxNavigateUp<cr>" },
      { "<c-l>", "<cmd><C-U>TmuxNavigateRight<cr>" },
    },
  },
  { -- map keys without delay when typing
    "max397574/better-escape.nvim",
    event = "InsertEnter",
    opts = {
      default_mappings = false,
      mappings = {
        i = {
          j = {
            k = "<Esc>",
            j = "<Esc>",
          },
        },
      },
    },
  },
  { -- Adds git related signs to the gutter, as well as utilities for managing changes.
    "lewis6991/gitsigns.nvim",
    opts = {
      signs = {
        add = { text = "A" },
        change = { text = "M" },
        delete = { text = "D" },
        topdelete = { text = "T" },
        changedelete = { text = "C" },
        untracked = { text = "?" },
      },
      attach_to_untracked = true,
      current_line_blame = true,
    },
  },
  {
    "echasnovski/mini.tabline", -- A minimal tabline plugin for neovim.
    opts = {
      show_icons = false,
      tabpage_section = "right",
      set_vim_settings = true,
    },
  },
  {
    "echasnovski/mini.statusline", -- A minimal statusline plugin for neovim.
    opts = {
      use_icons = false,
      set_vim_settings = true,
      content = {
        active = function()
          local statusline = require("mini.statusline")
          local mode, mode_hl = statusline.section_mode({ trunc_width = 120 })
          local git = statusline.section_git({ trunc_width = 75, icon = "GIT" })
          local diagnostics = statusline.section_diagnostics({ trunc_width = 75, icon = "LSP" })
          local filename = statusline.section_filename({ trunc_width = 140 })
          -- local fileinfo = statusline.section_fileinfo({ trunc_width = 120 })
          -- local location = statusline.section_location({ trunc_width = 75 })
          -- local search = statusline.section_searchcount({ trunc_width = 75 })
          local lint_progress = function()
            local linters = require("lint").get_running()
            if #linters == 0 then
              return ""
            end
            return " " .. table.concat(linters, ", ")
          end
          return statusline.combine_groups({
            { hl = mode_hl, strings = { mode } },
            { hl = "MiniStatuslineDevinfo", strings = { git, diagnostics, lint_progress() } },
            "%<", -- Mark general truncate point
            { hl = "MiniStatuslineFilename", strings = { filename } },
            "%=", -- End left alignment
            { hl = "MiniStatuslineFileinfo", strings = { vim.bo.filetype ~= "" and vim.bo.filetype } },
            { hl = mode_hl, strings = { "%l:%v" } },
            -- { hl = mode_hl, strings = { search, location } },
          })
        end,
      },
    },
  },
  { -- Highlight todo, notes, etc in comments.
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = { signs = false },
  },
  { -- Add/change/delete surrounding delimiter pairs with ease.
    "kylechui/nvim-surround",
    enabled = true,
    version = "*",
    event = "VeryLazy",
    config = function()
      require("nvim-surround").setup({})
    end,
  },
  { -- autopairs for neovim written in lua
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    dependencies = { "hrsh7th/nvim-cmp" },
    config = function()
      require("nvim-autopairs").setup({
        enable_check_bracket_line = false,
      })
      local cmp_autopairs = require("nvim-autopairs.completion.cmp")
      local cmp = require("cmp")
      cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
    end,
  },
}
