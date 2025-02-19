local M = {}

M.setup = function()
  local hl = vim.api.nvim_set_hl
  hl(0, "CursorLine", { bg = "#2D323B" })
  hl(0, "MiniCursorword", { bg = "#394B62" })
  hl(0, "Yank", { bg = "#394B62" })
  hl(0, "SnacksPicker", { bg = "#2F343E", fg = "#E6E6E6" })
  hl(0, "SnacksPickerTitle", { bg = "#2F343E", fg = "#ABB2BF" })
  hl(0, "SnacksPickerBorder", { bg = "#2F343E", fg = "#3C414C" })
  hl(0, "SnacksPickerListCursorLine", { bg = "#363C46" })
  hl(0, "SnacksPickerPrompt", { fg = "#98C379" })
  hl(0, "Visual", { bg = "#446181" })
  hl(0, "ColorColumn", { bg = "none", fg = "none" })
  hl(0, "VirtColumn", { fg = "#20232A" }) -- #5B5D64 #20232A
  hl(0, "GitSignsCurrentLineBlame", { fg = "#788CA6" })
end

return M.setup()
