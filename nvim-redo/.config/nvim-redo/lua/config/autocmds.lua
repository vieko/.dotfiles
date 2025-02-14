-- [[ AUTOCOMMANDS ]]
local function augroup(name)
  return vim.api.nvim_create_augroup("vieko_" .. name, { clear = true })
end
 
-- highlight when yanking (copying) text
vim.api.nvim_create_autocmd("TextYankPost", {
  group = augroup("highlight_yank"),
  callback = function()
    vim.highlight.on_yank()
  end,
})
