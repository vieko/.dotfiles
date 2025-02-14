-- [[ GIT SIGNS  ]]
return {
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
    },
  },
}

