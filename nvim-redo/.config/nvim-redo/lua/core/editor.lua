-- [[ EDITOR ]]
return {
  { -- detect tabstops and shiftwidth automatically
    "tpope/vim-sleuth",
  },
  { -- navigate between tmux and nvim panes
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
  { -- icons
    "echasnovski/mini.icons",
    version = false,
    opts = {
      style = "ascii",
      default = { hl = "MiniIconsGrey" },
    },
    config = function(_, options)
      local icons = require("mini.icons")
      local to_hex = require("utils.colors").to_hex
      local hl_groups = {
        "MiniIconsAzure",
        "MiniIconsBlue",
        "MiniIconsCyan",
        "MiniIconsGreen",
        "MiniIconsGrey",
        "MiniIconsOrange",
        "MiniIconsPurple",
        "MiniIconsRed",
        "MiniIconsYellow",
      }
      icons.setup(options)
      icons.mock_nvim_web_devicons()
      for _, group in ipairs(hl_groups) do
        vim.api.nvim_set_hl(0, group, { fg = to_hex(vim.g.tinted_gui05) })
      end
    end,
  },
  { -- Adds git related signs to the gutter, as well as utilities for managing changes.
    "lewis6991/gitsigns.nvim",
    event = "VeryLazy",
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
      on_attach = function(buffer)
        local gs = package.loaded.gitsigns

        local function map(mode, l, r, desc)
          vim.keymap.set(mode, l, r, { buffer = buffer, desc = desc })
        end

        map("n", "]c", function()
          gs.nav_hunk("next")
        end, "Go to next git change")
        map("n", "[c", function()
          gs.nav_hunk("prev")
        end, "Go to previous git change")
      end,
    },
  },
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    config = function()
      local ll = require("lualine")
      ll.setup({
        options = {
          icons_enabled = false,
          theme = "auto",
          component_separators = { left = "", right = "" },
          section_separators = { left = "", right = "" },
        },
        sections = {
          lualine_a = { "mode" },
          lualine_b = { "branch", "diff", "diagnostics" },
          lualine_c = { "filename" },
          lualine_x = { "encoding", "fileformat", "filetype" },
          lualine_y = { "progress" },
          lualine_z = { "location" },
        },
        inactive_sections = {
          lualine_a = {},
          lualine_b = {},
          lualine_c = { "filename" },
          lualine_x = { "location" },
          lualine_y = {},
          lualine_z = {},
        },
      })
    end,
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
}
