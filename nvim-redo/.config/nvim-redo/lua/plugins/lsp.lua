-- [[ LSP ]]
return {
  {
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {
      library = {
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
      },
    },
  },
  {
    -- Main LSP Configuration
    "neovim/nvim-lspconfig",
    dependencies = {
      { "williamboman/mason.nvim", opts = {} },
      "williamboman/mason-lspconfig.nvim",
      "WhoIsSethDaniel/mason-tool-installer.nvim",
      { -- Useful status updates for LSP.
        "j-hui/fidget.nvim",
        config = function()
          require("fidget").setup({
            progress = {
              display = {
                done_icon = "",
              },
            },
            notification = {
              window = {
                winblend = 0,
              },
            },
          })
        end,
      },
      "hrsh7th/cmp-nvim-lsp",
    },
    config = function()
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("kickstart-lsp-attach", { clear = true }),
        callback = function(event)
          local Snacks = require("snacks")

          local map = function(keys, func, desc, mode)
            mode = mode or "n"
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
          end

          map("gd", function()
            Snacks.picker.lsp_definitions()
          end, "Go to definition")
          map("gD", function()
            Snacks.picker.lsp_declarations()
          end, "Go to declaration")
          map("gy", function()
            Snacks.picker.lsp_type_definitions()
          end, "Go to type definition")
          map("gI", function()
            Snacks.picker.lsp_implementations()
          end, "Go to implementation")
          map("cd", vim.lsp.buf.rename, "Rename (change definition)")
          map("gA", function()
            Snacks.picker.lsp_references()
          end, "Go to all references to the current word")
          map("gs", function()
            Snacks.picker.lsp_symbols()
          end, "Find symbol in current file")
          map("gS", function()
            Snacks.picker.lsp_workspace_symbols()
          end, "Find symbol in entire project")
          map("gh", vim.lsp.buf.hover, "Show inline error (hover")
          map("g.", vim.lsp.buf.code_action, "Open the code actions menu", { "n", "x" })

          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client.supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
            local highlight_augroup = vim.api.nvim_create_augroup("kickstart-lsp-highlight", { clear = false })
            vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.document_highlight,
            })

            vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.clear_references,
            })

            vim.api.nvim_create_autocmd("LspDetach", {
              group = vim.api.nvim_create_augroup("kickstart-lsp-detach", { clear = true }),
              callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds({ group = "kickstart-lsp-highlight", buffer = event2.buf })
              end,
            })
          end
        end,
      })

      -- Change diagnostic symbols in the sign column (gutter)
      if vim.g.have_nerd_font then
        local signs = { ERROR = "E", WARN = "W", INFO = "I", HINT = "H" }
        local diagnostic_signs = {}
        for type, icon in pairs(signs) do
          diagnostic_signs[vim.diagnostic.severity[type]] = icon
        end
        vim.diagnostic.config({ signs = { text = diagnostic_signs } })
      end

      local capabilities = vim.lsp.protocol.make_client_capabilities()
      capabilities = vim.tbl_deep_extend("force", capabilities, require("cmp_nvim_lsp").default_capabilities())

      local servers = {
        tailwindcss = {},
        cssls = {},
        vtsls = {
          root_dir = require("lspconfig").util.root_pattern(
            ".git",
            "pnpm-workspace.yaml",
            "pnpm-lock.yaml",
            "yarn.lock",
            "package-lock.json",
            "bun.lockb"
          ),
          typescript = {
            tsserver = {
              maxTsServerMemory = 12288,
            },
          },
          experimental = {
            completion = {
              entriesLimit = 3,
            },
          },
        },
        lua_ls = {
          settings = {
            Lua = {
              completion = {
                callSnippet = "Replace",
              },
              diagnostics = { disable = { "missing-fields" } },
            },
          },
        },
      }

      local ensure_installed = vim.tbl_keys(servers or {})
      vim.list_extend(ensure_installed, {
        "stylua",
        "prettier",
        "cssls",
        "vtsls",
        "lua_ls",
        "eslint_d",
        "oxlint",
        "shellcheck",
      })
      require("mason-tool-installer").setup({ ensure_installed = ensure_installed })

      require("mason-lspconfig").setup({
        handlers = {
          function(server_name)
            local server = servers[server_name] or {}
            server.capabilities = vim.tbl_deep_extend("force", {}, capabilities, server.capabilities or {})
            require("lspconfig")[server_name].setup(server)
          end,
        },
      })
    end,
  },
}
