-- [[ SNACKS ]]
return {
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    config = function()
      local Snacks = require("snacks")
      local function map(mode, lhs, rhs, opts)
        local options = { noremap = true, silent = true }
        if opts then
          options = vim.tbl_extend("force", options, opts)
        end
        vim.keymap.set(mode, lhs, rhs, options)
      end
      Snacks.setup({
        explorer = { replace_netrw = true },
        picker = {
          ---@diagnostic disable-next-line: missing-fields
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
          win = {
            preview = {
              wo = {
                signcolumn = "yes:2",
              },
            },
          },
        },
        statuscolumn = {
          enabled = true,
          left = { "git", "sign" },
          right = { "mark", "fold" },
          git = {
            pattern = { "GitSign" },
          },
          refresh = 50,
        },
        bufdelete = { enabled = true },
        notifier = { enabled = true },
        bigfile = { enabled = true },
        words = { enabled = false },
        util = { enabled = true },
        image = { enabled = true },
        git = { enabled = true },
        win = { enabled = false },
      })

      -- SCRATCH BUFFER
      map("n", "<leader>.", function()
        Snacks.scratch()
      end, { desc = "Open scratch buffer" })
      -- HIGHLIGHT PICKER
      map("n", "<leader>h", function()
        Snacks.picker.highlights()
      end, { desc = "Show highlights" })
      -- KEYMAP
      map("n", "<leader>k", function()
        Snacks.picker.keymaps()
      end, { desc = "Show keymaps" })
      -- SMART PICKER
      map("n", "<leader><leader>", function()
        Snacks.picker.smart()
      end, { desc = "Smart find files" })
      -- EXPLORER
      map("n", "<C-b>", function()
        Snacks.explorer()
      end, { desc = "Open explorer" })
      -- FILE PICKER
      map("n", "<C-p>", function()
        Snacks.picker.pick("files")
      end, { desc = "Find files" })
      -- GREP SEARCH
      map("n", "g/", function()
        Snacks.picker.grep({ title = "Search all files" })
      end, { desc = "Search all files" })
      -- GREP WORD SEARCH
      map({ "n", "x" }, "gr", function()
        Snacks.picker.grep_word({ title = "Visual selection or word" })
      end, { desc = "Visual selection or word" })
      -- DELETE BUFFER
      map("n", "ZZ", function()
        Snacks.bufdelete()
      end, { desc = "Delete buffer" })
      -- GIT BLAME
      map("n", "gb", function()
        Snacks.git.blame_line()
      end, { desc = "Blame line" })
      -- DIAGNOSTICS
      map("n", "gh", function()
        Snacks.picker.diagnostics({
          finder = "diagnostics",
          format = "diagnostic",
          sort = {
            fields = {
              "is_current",
              "is_cwd",
              "severity",
              "file",
              "lnum",
            },
          },
          matcher = { sort_empty = true },
          filter = { cwd = true },
          layout = { preset = "select" },
        })
      end, { desc = "Show diagnostics" })
    end,
  },
}
