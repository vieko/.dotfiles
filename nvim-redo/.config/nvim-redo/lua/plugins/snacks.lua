-- [[ SNACKS ]]
return {
  {
    "folke/snacks.nvim",
    dependencies = {
      { "echasnovski/mini.icons", version = false, opts = { style = "ascii" } },
    },
    priority = 1000,
    lazy = false,
    opts = {
      explorer = {
        replace_netrw = true,
      },
      picker = {
        icons = {
          git = {
            enabled = true, -- show git icons
            commit = "C ", -- used by git log
            staged = "S", -- staged changes. always overrides the type icons
            added = "A",
            deleted = "D",
            ignored = "I ",
            modified = "M",
            renamed = "R",
            unmerged = "U ",
            untracked = "?",
          },
          diagnostics = {
            Error = "E ",
            Warn = "W ",
            Hint = "H ",
            Info = "I ",
          },
        },
      },
      bufdelete = {},
      notifier = { enabled = true },
      bigfile = {},
      words = {},
      ui = {},
    },
    keys = {
      {
        "<leader>.",
        function()
          Snacks.scratch()
        end,
        desc = "Toggle scratch buffer",
      },
      {
        "<leader><leader>",
        function()
          Snacks.picker.smart()
        end,
        desc = "Smart find files",
      },
      {
        "<C-b>",
        function()
          Snacks.explorer()
        end,
        desc = "Open explorer",
      },
      {
        "<C-p>",
        function()
          Snacks.picker.pick("files")
        end,
        desc = "Find files",
      },
      {
        "g/",
        function()
          Snacks.picker.grep({ title = "Search all files", icons = { ui = { live = "" } } })
        end,
        desc = "Search all files",
      },
      {
        "ZZ",
        function()
          Snacks.bufdelete()
        end,
        desc = "Delete buffer",
      },
    },
  },
}
