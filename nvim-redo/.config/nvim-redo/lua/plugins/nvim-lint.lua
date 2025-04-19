return {
  {
    "williamboman/mason.nvim",
    optional = true,
    opts = {
      ensure_installed = {
        "eslint_d",
        "oxlint",
        "shellcheck",
        "golangci-lint",  -- add golangci-lint to mason
      },
    },
  },
  {
    "mfussenegger/nvim-lint",
    event = "VeryLazy",
    opts = {
      linters_by_ft = {
        sh = { "shellcheck" },
        javascript = { "oxlint" },
        typescript = { "oxlint" },
        javascriptreact = { "oxlint" },
        typescriptreact = { "oxlint" },
        go = { "golangcilint" },  -- register for Go files
      },
      linters = {
        eslint_d = {
          args = {
            "--no-warn-ignored", -- Ignore warnings, support Eslint 9
            "--format",
            "json",
            "--stdin",
            "--stdin-filename",
            function()
              return vim.api.nvim_buf_get_name(0)
            end,
          },
        },
        -- Define a custom golangcilint linter that points to the correct executable
        golangcilint = {
          cmd = "golangci-lint", -- Point to the executable with hyphen
          args = {
            'run',
            '--out-format',
            'json',
            '--issues-exit-code=0',
            '--show-stats=false',
            '--print-issued-lines=false',
            '--print-linter-name=false',
            function()
              return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":h")
            end
          },
          stdin = false,
          append_fname = false,
          stream = "stdout",
          ignore_exitcode = true,
          parser = function(output, bufnr)
            if output == '' then
              return {}
            end
            local decoded = vim.json.decode(output)
            if decoded["Issues"] == nil or type(decoded["Issues"]) == 'userdata' then
              return {}
            end

            local diagnostics = {}
            for _, item in ipairs(decoded["Issues"]) do
              local curfile = vim.api.nvim_buf_get_name(bufnr)
              local curfile_abs = vim.fn.fnamemodify(curfile, ":p")

              local lintedfile = vim.fn.getcwd() .. "/" .. item.Pos.Filename
              local lintedfile_abs = vim.fn.fnamemodify(lintedfile, ":p")

              if curfile_abs == lintedfile_abs then
                -- only publish if those are the current file diagnostics
                local severity = vim.diagnostic.severity.WARN
                if item.Severity == "error" then
                  severity = vim.diagnostic.severity.ERROR
                elseif item.Severity == "warning" then
                  severity = vim.diagnostic.severity.WARN
                elseif item.Severity == "info" then
                  severity = vim.diagnostic.severity.INFO
                elseif item.Severity == "hint" then
                  severity = vim.diagnostic.severity.HINT
                end
                
                table.insert(diagnostics, {
                  lnum = item.Pos.Line > 0 and item.Pos.Line - 1 or 0,
                  col = item.Pos.Column > 0 and item.Pos.Column - 1 or 0,
                  end_lnum = item.Pos.Line > 0 and item.Pos.Line - 1 or 0,
                  end_col = item.Pos.Column > 0 and item.Pos.Column - 1 or 0,
                  severity = severity,
                  source = item.FromLinter,
                  message = item.Text,
                })
              end
            end
            return diagnostics
          end,
        },
      },
    },
    config = function(_, opts)
      local lint = require("lint")
      lint.linters_by_ft = opts.linters_by_ft

      -- Register our custom linters
      for name, linter in pairs(opts.linters) do
        lint.linters[name] = linter
      end

      -- Ignore issue with missing eslint config file
      lint.linters.eslint_d = require("lint.util").wrap(lint.linters.eslint_d, function(diagnostic)
        if diagnostic.message:find("Error: Could not find config file") then
          return nil
        end
        return diagnostic
      end)

      vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
        callback = function()
          local names = lint._resolve_linter_by_ft(vim.bo.filetype)

          -- Create a copy of the names table to avoid modifying the original.
          names = vim.list_extend({}, names)

          -- Add fallback linters.
          if #names == 0 then
            vim.list_extend(names, lint.linters_by_ft["_"] or {})
          end

          -- Add global linters.
          vim.list_extend(names, lint.linters_by_ft["*"] or {})

          -- Run linters.
          if #names > 0 then
            -- Check the if the linter is available, otherwise it will throw an error.
            for _, name in ipairs(names) do
              -- Skip the executable check - trust our custom defined linters
              if lint.linters[name] == nil then 
                vim.notify("Linter " .. name .. " is not available", vim.log.levels.INFO)
              else
                -- Run the linter
                lint.try_lint(name)
              end
            end
          end
        end,
      })
    end,
  },
}