-- [[ TREESITTER ]]
return {
  { -- highlight, edit, and navigate code
    "nvim-treesitter/nvim-treesitter",
    version = false,
    dependencies = {
      "nvim-treesitter/nvim-treesitter-textobjects",
    },
    build = ":TSUpdate",
    event = { "VeryLazy" },
    lazy = vim.fn.argc(-1) == 0,
    init = function(plugin)
      require("lazy.core.loader").add_to_rtp(plugin)
      require("nvim-treesitter.query_predicates")
    end,
    cmd = { "TSUpdateSync", "TSUpdate", "TSInstall" },
    keys = {
      { "<c-Space>", desc = "Increment Selection" },
      { "<BS>", desc = "Decrement Selection", mode = "x" },
    },
    opts_extend = { "ensure_installed" },
    opts = {
      highlight = { enable = true },
      indent = { enable = true },
      auto_install = true,
      ensure_installed = {
        "bash",
        "regex",
        "vim",
        "vimdoc",
        "lua",
        "luadoc",
        "html",
        "markdown",
        "markdown_inline",
        "css",
        "typescript",
        "javascript",
        "tsx",
        "json",
        "json5",
        "jsonc",
        "graphql",
        "prisma",
        "rust",
        "go",
        "toml",
        "c",
        "proto",
        "svelte",
        "astro",
        "embedded_template",
        "diff",
        "http",
      },
      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = "<C-Space>",
          node_incremental = "<C-Space>",
          scope_incremental = false,
          node_decremental = "<BS>",
        },
      },
      textobjects = {
        move = {
          enable = true,
          goto_next_start = { ["]f"] = "@function.outer", ["]c"] = "@class.outer", ["]a"] = "@parameter.inner" },
          goto_next_end = { ["]F"] = "@function.outer", ["]C"] = "@class.outer", ["]A"] = "@parameter.inner" },
          goto_previous_start = { ["[f"] = "@function.outer", ["[c"] = "@class.outer", ["[a"] = "@parameter.inner" },
          goto_previous_end = { ["[F"] = "@function.outer", ["[C"] = "@class.outer", ["[A"] = "@parameter.inner" },
        },
        select = {
          enable = true,
          keymaps = {
            ["af"] = "@function.outer",
            ["if"] = "@function.inner",
            ["ac"] = "@class.outer",
            ["ic"] = { query = "@class.inner", desc = "Select inner part of a class region" },
          },
        },
      },
    },
    ---@param opts TSConfig
    config = function(_, opts)
      require("nvim-treesitter.configs").setup(opts)
    end,
  },
  -- Use treesitter to auto close and auto rename html tag
  {
    "windwp/nvim-ts-autotag",
    event = "BufReadPre",
    opts = {},
  },
  -- Auto highlight word under cursor
  {
    "echasnovski/mini.cursorword",
    event = "LspAttach",
    opts = { delay = 100 },
    enabled = false,
  },
}
