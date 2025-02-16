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
    "nvim-lualine/lualine.nvim",
    opts = {},
  },
  {
    "akinsho/bufferline.nvim",
    event = "VeryLazy",
    config = function()
      local bl = require("bufferline")
      local to_hex = require("utils.colors").to_hex
      bl.setup({
        highlights = {
          separator = {
            fg = to_hex(vim.g.tinted_gui01),
          },
        },
        options = {
          indicator = {
            icon = " ",
            style = "none",
          },
          style_preset = {
            bl.style_preset.no_bold,
            bl.style_preset.no_italic,
          },
          numbers = function(opts)
            return string.format("%s", opts.ordinal)
          end,
          buffer_close_icon = "",
          modified_icon = " ",
          close_icon = " ",
          left_trunc_marker = " ",
          right_trunc_marker = " ",
          separator_style = { " | ", " | " },
          show_buffer_close_icons = false,
          show_close_icon = false,
          show_tab_indicators = false,
          diagnostics = "nvim_lsp",
          enforce_regular_tabs = false,
          always_show_bufferline = true,
          sort_by = "insert_at_end",
          offsets = {
            {
              filetype = "snacks_layout_box",
            },
          },
        },
      })
      vim.api.nvim_create_autocmd({ "BufAdd", "BufDelete" }, {
        callback = function()
          vim.schedule(function()
            pcall(nvim_bufferline)
          end)
        end,
      })
    end,
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
