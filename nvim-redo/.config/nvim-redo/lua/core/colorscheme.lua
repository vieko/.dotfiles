-- [[ COLORSCHEME ]]
return {
  {
    "tinted-theming/tinted-vim",
    enabled = false,
    priority = 1000,
    lazy = false,
  },
  {
    "brenoprata10/nvim-highlight-colors",
    enabled = false,
    config = function()
      require("nvim-highlight-colors").setup({})
    end,
    lazy = false,
  },
}
