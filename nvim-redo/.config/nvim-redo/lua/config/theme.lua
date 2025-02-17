local theme_script_path = vim.fn.expand("~/.local/share/tinted-theming/tinty/tinted-vim-colors-file.vim")

local function file_exists(file_path)
  return vim.fn.filereadable(file_path) == 1 and true or false
end

local function handle_focus_gained()
  if file_exists(theme_script_path) then
    vim.cmd("source " .. theme_script_path)
  end
end

local group = vim.api.nvim_create_augroup("Arcana", { clear = true })

if file_exists(theme_script_path) then
  vim.o.termguicolors = true
  vim.g.tinted_colorspace = 256
  vim.g.tinted_background_transparent = 1

  vim.cmd("source " .. theme_script_path)

  vim.api.nvim_create_autocmd("FocusGained", {
    group = group,
    pattern = "VeryLazy",
    callback = handle_focus_gained,
  })
end
