-- [[ LSPCONFIG ]]
local Lsp = require("utils.lsp")

local diagnostics = {
  Error = "E ",
  Warn = "W ",
  Hint = "H ",
  Info = "I ",
}

local setup_keymaps = function(client, buffer)
  local Snacks = require("snacks")
  local map = function(keys, func, desc, mode)
    mode = mode or "n"
    vim.keymap.set(mode, keys, func, { buffer = buffer, desc = "LSP: " .. desc })
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
  map("K", vim.lsp.buf.hover, "Show hover")
  map("g.", vim.lsp.buf.code_action, "Open the code actions menu", { "n", "x" })

  if client and client.server_capabilities.inlayHintProvider and vim.lsp.inlay_hint then
    map("<leader>th", function()
      require("utils.toggle").inlay_hints(buffer)
    end, "Toggle inlay hints")
  end
end

return {
  { -- lspconfig
    "neovim/nvim-lspconfig",
    event = "VeryLazy",
    dependencies = {
      "mason.nvim",
      "williamboman/mason-lspconfig.nvim",
    },
    ---@class PluginLspOpts
    ---@field diagnostics {underline: boolean, update_in_insert: boolean, virtual_text: {spacing: number, source: string, prefix: string}, severity_sort: boolean, signs: {text: table<number, string>}}
    ---@field inlay_hints {enabled: boolean, exclude?: string[]}
    ---@field capabilities table<string, any>
    ---@field servers table<string, any>
    ---@field setup table<string, fun(server:string, opts:table):boolean?>
    opts = function()
      return {
        diagnostics = {
          underline = true,
          update_in_insert = false,
          virtual_text = {
            spacing = 4,
            source = "if_many",
            prefix = "",
          },
          severity_sort = true,
          signs = {
            text = {
              [vim.diagnostic.severity.ERROR] = diagnostics.Error,
              [vim.diagnostic.severity.WARN] = diagnostics.Warn,
              [vim.diagnostic.severity.HINT] = diagnostics.Hint,
              [vim.diagnostic.severity.INFO] = diagnostics.Info,
            },
          },
        },
        inlay_hints = {
          enabled = false,
          exclude = {},
        },
        capabilities = {
          workspace = {
            fileOperations = {
              didRename = true,
              willRename = true,
            },
          },
        },
        ---@type lspconfig.options
        servers = {
          cssls = {
            settings = {
              css = {
                lint = {
                  unknownAtRules = "ignore",
                },
              },
            },
          },
        },
        ---@type table<string, fun(server:string, opts:lspconfig.options):boolean?>
        setup = {},
      }
    end,
    ---@param opts PluginLspOpts
    config = function(_, opts)
      Lsp.on_attach(setup_keymaps)
      Lsp.setup()
      Lsp.on_dynamic_capability(setup_keymaps)

      -- diagnostics signs
      if type(opts.diagnostics.signs) ~= "boolean" then
        for severity, icon in pairs(opts.diagnostics.signs.text) do
          local name = vim.diagnostic.severity[severity]:lower():gsub("^%l", string.upper)
          name = "DiagnosticSign" .. name
          vim.fn.sign_define(name, { text = icon, texthl = name, numhl = "" })
        end
      end

      -- inlay hints
      if opts.inlay_hints.enabled then
        require("utils.lsp").on_supports_method("textDocument/inlayHint", function(_, buffer)
          if
            vim.api.nvim_buf_is_valid(buffer)
            and vim.bo[buffer].buftype == ""
            and not vim.tbl_contains(opts.inlay_hints.exclude, vim.bo[buffer].filetype)
          then
            require("utils.toggle").inlay_hints(buffer, true)
          end
        end)
      end

      vim.diagnostic.config(vim.deepcopy(opts.diagnostics))

      local servers = opts.servers
      local has_cmp, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
      local capabilities = vim.tbl_deep_extend(
        "force",
        {},
        vim.lsp.protocol.make_client_capabilities(),
        has_cmp and cmp_nvim_lsp.default_capabilities(),
        opts.capabilities or {}
      )

      local function setup(server)
        local server_opts = vim.tbl_deep_extend("force", {
          capabilities = vim.deepcopy(capabilities),
        }, servers[server] or {})

        if opts.setup[server] then
          if opts.setup[server](server, server_opts) then
            return
          end
        elseif opts.setup["*"] then
          if opts.setup["*"](server, server_opts) then
            return
          end
        end
        require("lspconfig")[server].setup(server_opts)
      end

      local have_mason, mlsp = pcall(require, "mason-lspconfig")
      local all_mslp_servers = {}
      if have_mason then
        all_mslp_servers = vim.tbl_keys(require("mason-lspconfig.mappings.server").lspconfig_to_package)
      end

      local ensure_installed = {} ---@type string[]
      for server, server_opts in pairs(servers) do
        if server_opts then
          server_opts = server_opts == true and {} or server_opts
          if server_opts.enabled ~= false then
            if server_opts.mason == false or not vim.tbl_contains(all_mslp_servers, server) then
              setup(server)
            else
              ensure_installed[#ensure_installed + 1] = server
            end
          end
        end
      end

      if have_mason then
        ---@diagnostic disable-next-line: missing-fields
        mlsp.setup({
          ensure_installed = vim.tbl_deep_extend("force", ensure_installed, {}),
          handlers = { setup },
        })
      end
    end,
  },
  { -- cmdline tools and lsp servers
    "williamboman/mason.nvim",
    cmd = "Mason",
    build = ":MasonUpdate",
    opts_extend = { "ensure_installed" },
    opts = {
      ensure_installed = {
        "stylua",
        "eslint-lsp",
        "tailwindcss-language-server",
        "golangci-lint",
      },
      ui = {
        border = "rounded",
      },
    },
    ---@param opts MasonSettings | {ensure_installed: string[]}
    config = function(_, opts)
      require("mason").setup(opts)
      local mr = require("mason-registry")
      mr:on("package:install:success", function()
        vim.defer_fn(function()
          require("lazy.core.handler.event").trigger({
            event = "FileType",
            buf = vim.api.nvim_get_current_buf(),
          })
        end, 100)
      end)

      mr.refresh(function()
        for _, tool in ipairs(opts.ensure_installed) do
          local p = mr.get_package(tool)
          if not p:is_installed() then
            p:install()
          end
        end
      end)
    end,
  },
}
