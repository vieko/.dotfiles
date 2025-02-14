-- [[ MINI ]]
return {
  {
    "echasnovski/mini.statusline", -- A minimal statusline plugin for neovim.
    opts = {
      use_icons = false,
      set_vim_settings = false,
      content = {
        active = function()
          local statusline = require("mini.statusline")
          local mode, mode_hl = statusline.section_mode({ trunc_width = 120 })
          local git = statusline.section_git({ trunc_width = 75, icon = "GIT" })
          local diagnostics = statusline.section_diagnostics({ trunc_width = 75, icon = "LSP" })
          local filename = statusline.section_filename({ trunc_width = 140 })
          -- local fileinfo = statusline.section_fileinfo({ trunc_width = 120 })
          -- local location = statusline.section_location({ trunc_width = 75 })
          -- local search = statusline.section_searchcount({ trunc_width = 75 })
          local lint_progress = function()
            local linters = require("lint").get_running()
            if #linters == 0 then
              return ""
            end
            return " " .. table.concat(linters, ", ")
          end
          return statusline.combine_groups({
            { hl = mode_hl, strings = { mode } },
            { hl = "MiniStatuslineDevinfo", strings = { git, diagnostics, lint_progress() } },
            "%<", -- Mark general truncate point
            { hl = "MiniStatuslineFilename", strings = { filename } },
            "%=", -- End left alignment
            { hl = "MiniStatuslineFileinfo", strings = { vim.bo.filetype ~= "" and vim.bo.filetype } },
            { hl = mode_hl, strings = { "%l:%v" } },
            -- { hl = mode_hl, strings = { search, location } },
          })
        end,
      },
    },
  },
}
