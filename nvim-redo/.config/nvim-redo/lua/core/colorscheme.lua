-- [[ COLORSCHEME ]]
return {
  {
    "tinted-theming/tinted-vim",
    priority = 1000,
    lazy = false,
  },
  {
    "folke/tokyonight.nvim",
    lazy = false,
    enabled = false,
    priority = 1000,
    opts = {},
  },
  {
    "navarasu/onedark.nvim",
    priority = 1000,
    enabled = false,
    lazy = false,
    opts = {
      style = "dark",
      transparent = true,
      code_style = {
        comments = "none",
      },
      diagnostics = {
        darker = true,
        undercurl = true,
        background = false,
      },
      colors = {},
      highlight = {},
    },
  },
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    lazy = false,
    enabled = false,
    config = function()
      require("catppuccin").setup({
        flavour = "auto",
        background = {
          light = "latte",
          dark = "mocha",
        },
        term_colors = true,
        dim_inactive = {
          enabled = true,
        },
        highlight_overrides = {
          all = function(colors)
            return {
              CursorLineNr = { fg = colors.peach, bold = true },
              CopilotSuggestion = { fg = colors.surface1 },
              NeoTreeModified = { fg = colors.text },
              NeoTreeFadeText1 = { fg = colors.surface1 },
              NeoTreeFadeText2 = { fg = colors.surface1 },
              NeoTreeDotfile = { fg = colors.surface1 },
              NeoTreeDimText = { fg = colors.surface1 },
              NeoTreeHiddenByName = { fg = colors.surface1 },
              NeoTreeWindowsHidden = { fg = colors.surface1 },
            }
          end,
        },
        integrations = {
          fidget = true,
          flash = true,
          gitsigns = true,
          mason = true,
          mini = {
            enabled = true,
            indentscope_color = "",
          },
          cmp = true,
          native_lsp = {
            enabled = true,
            virtual_text = {
              errors = { "italic" },
              hints = { "italic" },
              warnings = { "italic" },
              information = { "italic" },
            },
            underlines = {
              errors = { "underline" },
              hints = { "underline" },
              warnings = { "underline" },
              information = { "underline" },
            },
            inlay_hints = {
              background = true,
            },
          },
          treesitter = true,
          telescope = { enabled = true, style = "classic" },
          which_key = true,
          lsp_trouble = false,
        },
      })
    end,
  },
}
