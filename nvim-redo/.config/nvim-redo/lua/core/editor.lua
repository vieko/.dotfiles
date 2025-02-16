-- [[ EDITOR ]]
local default_bufferline_style = { bold = false, italic = false }
local bufferline_highlight_keys = {
  "fill",
  "background",
  "tab",
  "tab_selected",
  "tab_separator",
  "tab_separator_selected",
  "tab_close",
  "close_button",
  "close_button_visible",
  "close_button_selected",
  "buffer_visible",
  "buffer_selected",
  "numbers",
  "numbers_visible",
  "numbers_selected",
  "diagnostic",
  "diagnostic_visible",
  "diagnostic_selected",
  "hint",
  "hint_visible",
  "hint_selected",
  "hint_diagnostic",
  "hint_diagnostic_visible",
  "hint_diagnostic_selected",
  "info",
  "info_visible",
  "info_selected",
  "info_diagnostic",
  "info_diagnostic_visible",
  "info_diagnostic_selected",
  "warning",
  "warning_visible",
  "warning_selected",
  "warning_diagnostic",
  "warning_diagnostic_visible",
  "warning_diagnostic_selected",
  "error",
  "error_visible",
  "error_selected",
  "error_diagnostic",
  "error_diagnostic_visible",
  "error_diagnostic_selected",
  "modified",
  "modified_visible",
  "modified_selected",
  "duplicate_selected",
  "duplicate_visible",
  "duplicate",
  "separator_selected",
  "separator_visible",
  "separator",
  "indicator_visible",
  "indicator_selected",
  "pick_selected",
  "pick_visible",
  "pick",
  "offset_separator",
  "trunc_marker",
}

local bufferline_highlights = {}

for _, key in ipairs(bufferline_highlight_keys) do
  bufferline_highlights[key] = default_bufferline_style
end

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
    opts = {
      highlights = bufferline_highlights,
      options = {
        indicator = {
          icon = " ",
          style = "none",
        },
        style_preset = function()
          local bufferline = require("bufferline")
          return {
            bufferline.style_preset.no_bold,
            bufferline.style_preset.no_italic,
          }
        end,
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
        -- stylua: ignore
        close_command = function(n) Snacks.bufdelete(n) end,
        diagnostics = "nvim_lsp",
        enforce_regular_tabs = true,
        always_show_bufferline = true,
        offsets = {
          {
            filetype = "snacks_layout_box",
          },
        },
        sort_by = "insert_after_current",
      },
    },
    config = function(_, opts)
      require("bufferline").setup(opts)
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
