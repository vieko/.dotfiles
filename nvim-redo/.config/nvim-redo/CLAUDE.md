# Neovim Configuration Guide

## Commands
- **Format**: Run formatters on current buffer
- **FormatDisable/FormatEnable**: Toggle autoformatting
- **ToggleEslint**: Toggle ESLint integration
- **EslintFixAll**: Fix all ESLint issues in buffer

## Code Style
- **Lua**: 120 column width, 2-space indent, double quotes, explicit parentheses
- **Module Pattern**: `local M = {} ... return M`
- **Documentation**: Use LuaLS annotations (`---@param`, `---@return`)
- **Types**: Include explicit typing with `---@type` annotations
- **Sections**: Use clear comment headers `-- [[ SECTION NAME ]]`

## Formatters & Linters
- **Lua**: stylua
- **JS/TS**: biome → prettier/prettierd → dprint (fallback chain)
- **CSS**: prettierd → prettier
- **Shell**: shfmt (+ shellcheck for linting)
- **Tailwind**: rustywind for class sorting

## Project Structure
- `config/`: Core configuration (options, keymaps)
- `core/`: Core functionality modules
- `langs/`: Language-specific configurations
- `plugins/`: Plugin-specific configurations
- `utils/`: Utility functions and helpers

Use lazy.nvim module pattern with clear separation of concerns.