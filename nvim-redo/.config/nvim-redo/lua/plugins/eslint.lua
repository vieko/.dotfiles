local enable_eslint = vim.g.lsp_eslint_enable == "yes" or false

local Lsp = require("utils.lsp")

local eslint_config = {
  settings = {
    workingDirectories = { mode = "auto" },
    experimental = {
      useFlatConfig = true,
    },
  },
}

local function toggle_eslint()
  enable_eslint = not enable_eslint
  if enable_eslint then
    Lsp.start_lsp_client_by_name("eslint", eslint_config)
    vim.cmd(":e") -- Workaround for the LSP on_attach function not being triggered
  else
    Lsp.stop_lsp_client_by_name("eslint")
  end
end

vim.api.nvim_create_user_command("ToggleEslint", toggle_eslint, {
  desc = "Toggle ESLint LSP",
})

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        eslint = eslint_config,
      },
      setup = {
        eslint = function()
          if enable_eslint == false then
            return true
          end
          Lsp.on_attach(function(client, bufnr)
            if client.name == "eslint" then
              vim.api.nvim_create_autocmd("BufWritePre", {
                buffer = bufnr,
                command = "EslintFixAll",
              })
            end
          end)
        end,
      },
    },
  },
}
