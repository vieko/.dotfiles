-- [[ SNACKS ]]
return {
  {
    "folke/snacks.nvim",
    dependencies = {
      { "echasnovski/mini.icons", version = false, opts = { style = "ascii" } },
    },
    priority = 1000,
    lazy = false,
    ---@type snacks.Config
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
      notifier = { enabled = false },
      bigfile = {},
      words = {},
    },
    keys = {
      {
        "<C-b>",
        function()
          Snacks.explorer()
        end,
        desc = "Open Explorer",
      },
      {
        "<C-p>",
        function()
          Snacks.picker.pick("files")
        end,
        desc = "Find Files",
      },
      {
        "g/",
        function()
          Snacks.picker.grep({ title = "Search All Files", icons = { ui = { live = "" } } })
        end,
        desc = "Search All Files",
      },
      {
        "<leader><leader>",
        function()
          Snacks.picker.smart()
        end,
        desc = "Smart Find Files",
      },
      {
        "ZZ",
        function()
          Snacks.bufdelete()
        end,
        desc = "Delete Buffer",
      },
    },
  },
}
