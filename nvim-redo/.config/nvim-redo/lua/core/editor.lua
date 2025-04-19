-- [[ EDITOR ]]
local highlight = require("config/highlights")
local colors = highlight.colors
local defaults = highlight.defaults
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
    opts = { style = "ascii" },
    config = function(_, options)
      local icons = require("mini.icons")
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
        vim.api.nvim_set_hl(0, group, { fg = colors.gui05 })
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
      signs_staged = {
        add = { text = "A" },
        change = { text = "M" },
        delete = { text = "D" },
        topdelete = { text = "T" },
        changedelete = { text = "C" },
        untracked = { text = "?" },
      },
      signs_staged_enable = true,
      attach_to_untracked = true,
      current_line_blame = true,
      current_line_blame_opts = {
        virt_text = true,
        virt_text_pos = "eol",
        delay = 0,
      },
      current_line_blame_formatter = "       <author>, <author_time:%R> ", -- " <author>, <author_time:%R> - <summary> "
      current_line_blame_formatter_nc = "",
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
        map("n", "di", function()
          gs.diffthis("~")
        end, "Diff this")
        map("n", "do", function()
          gs.preview_hunk_inline()
        end, "Expand diff hunk")
        map("n", "dO", function()
          gs.stage_hunk()
        end, "Toggle staged")
        map("n", "du", function()
          gs.stage_hunk()
          gs.nav_hunk("next")
        end, "Stage hunk and go to next")
        map("n", "dp", function()
          gs.reset_hunk()
        end, "Restore change")
      end,
    },
  },
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    init = function()
      vim.g.lualine_laststatus = vim.o.laststatus
      if vim.fn.argc(-1) > 0 then
        vim.o.statusline = " "
      else
        vim.o.laststatus = 0
      end
    end,
    config = function()
      local ll = require("lualine")
      vim.o.laststatus = vim.g.lualine_laststatus
      ll.setup({
        options = {
          theme = "onedark",
          icons_enabled = false,
          component_separators = { left = "", right = "" },
          section_separators = { left = "", right = "" },
          globalstatus = vim.o.laststatus == 3,
        },
        sections = {
          lualine_a = { "mode" },
          lualine_b = { "branch" },
          lualine_c = {
            {
              "diagnostics",
              symbols = {
                error = "E",
                warn = "W",
                info = "I",
                hint = "H",
              },
            },
          },
          lualine_x = {
            {
              "diff",
              symbols = {
                added = "A",
                modified = "M",
                removed = "R",
              },
              source = function()
                local gitsigns = vim.b.gitsigns_status_dict
                if gitsigns then
                  return {
                    added = gitsigns.added,
                    modified = gitsigns.changed,
                    removed = gitsigns.removed,
                  }
                end
              end,
            },
          },
          lualine_y = {
            { "progress", separator = " ", padding = { left = 1, right = 1 } },
          },
          lualine_z = {
            { "location", padding = { left = 1, right = 1 } },
          },
        },
      })
    end,
  },
  {
    "akinsho/bufferline.nvim",
    event = "VeryLazy",
    config = function()
      local bl = require("bufferline")
      bl.setup({
        options = {
          indicator = {
            icon = " ",
            style = "none",
          },
          style_preset = {
            bl.style_preset.minimal,
            bl.style_preset.no_italic,
            bl.style_preset.no_bold,
          },
          numbers = function(opts)
            return string.format("%s", opts.ordinal)
          end,
          buffer_close_icon = "",
          modified_icon = " ",
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
  { -- notifications
    "folke/noice.nvim",
    event = "VeryLazy",
    opts = {
      lsp = {
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
          ["cmp.entry.get_documentation"] = true,
        },
        hover = {
          enabled = true,
          silent = true,
        },
      },
      routes = {
        {
          view = "notify",
          filter = { event = "msg_showmode" },
        },
        {
          filter = {
            event = "msg_show",
            any = {
              { find = "%d+L, %d+B" },
              { find = "; after #%d+" },
              { find = "; before #%d+" },
            },
          },
          view = "mini",
        },
      },
      cmdline = {
        format = {
          cmdline = { icon = " " },
          search_down = { icon = " " },
          search_up = { icon = " " },
          filter = { icon = " " },
          lua = { icon = " " },
          help = { icon = " " },
          input = { icon = " " },
        },
      },
      presets = {
        bottom_search = false,
        command_palette = true,
        long_message_to_split = true,
      },
      views = {
        hover = {
          view = "popup",
          relative = "cursor",
          zindex = 45,
          enter = false,
          anchor = "auto",
          size = {
            width = "auto",
            height = "auto",
            max_height = 20,
            max_width = 120,
          },
          border = {
            style = "none",
            padding = { 1, 2 },
          },
          position = { row = 2, col = 0 },
          win_options = {
            wrap = true,
            linebreak = true,
          },
        },
      },
    },
    config = function(_, opts)
      -- HACK: noice shows messages from before it was enabled,
      -- but this is not ideal when Lazy is installing plugins,
      -- so clear the messages in this case.
      if vim.o.filetype == "lazy" then
        vim.cmd([[messages clear]])
      end
      require("noice").setup(opts)
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
  {
    "lukas-reineke/virt-column.nvim",
    event = "VeryLazy",
    config = function()
      require("virt-column").setup({
        enabled = true,
        char = "│", -- │ ╎ ┆ ┊
        virtcolumn = "80",
        highlight = "VirtColumn",
      })
    end,
  },
}
