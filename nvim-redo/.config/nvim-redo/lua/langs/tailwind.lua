-- [[ TAILWIND ]]
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        tailwindcss = {
          filetypes_exclude = { "markdown" },
          filetypes_include = {},
        },
      },
      setup = {
        tailwindcss = function(_, opts)
          local tw = require("lspconfig.configs.tailwindcss")
          opts.filetypes = opts.filetypes or {}

          vim.list_extend(opts.filetypes, tw.default_config.filetypes)

          --- @param ft string
          opts.filetypes = vim.tbl_filter(function(ft)
            return not vim.tbl_contains(opts.filetypes_exclude or {}, ft)
          end, opts.filetypes)

          vim.list_extend(opts.filetypes, opts.filetypes_include or {})

          -- Project-specific tailwind CSS entrypoint configurations
          -- Map: { [project_path]: { css_file: string, patterns: string[] } }
          local project_configs = {
            ["/home/vieko/dev/mothership"] = {
              css_file = "/home/vieko/dev/mothership/packages/ui/src/styles/globals.css",
              patterns = {
                "/home/vieko/dev/mothership/apps/influencer/**/*",
                "/home/vieko/dev/mothership/apps/website/**/*",
                "/home/vieko/dev/mothership/packages/ui/**/*",
              },
            },
            -- Add more projects as needed
          }

          -- Get the project root directory
          local current_dir = vim.fn.getcwd()
          local project_root = nil

          -- Find which project config applies
          for project_path, _ in pairs(project_configs) do
            if vim.startswith(current_dir, project_path) then
              project_root = project_path
              break
            end
          end

          if project_root then
            -- Set up the configFile object according to Tailwind CSS v4 format
            local config = project_configs[project_root]

            -- Initialize settings structure
            opts.settings = opts.settings or {}
            opts.settings.tailwindCSS = opts.settings.tailwindCSS or {}
            opts.settings.tailwindCSS.experimental = opts.settings.tailwindCSS.experimental or {}

            -- Create the configFile object: { [css_file_path]: patterns_it_applies_to }
            local configFile = {}
            configFile[config.css_file] = config.patterns

            -- Set the configFile in the settings
            opts.settings.tailwindCSS.experimental.configFile = configFile

            -- Notify for debugging with full configuration
            vim.notify(
              "Tailwind CSS configured for project: "
                .. project_root
                .. "\nUsing CSS file: "
                .. config.css_file
                .. "\nFull config: "
                .. vim.inspect(opts.settings.tailwindCSS.experimental.configFile),
              vim.log.levels.INFO
            )
          else
            -- Default configuration if no project-specific config exists
            opts.settings = opts.settings or {}
            opts.settings.tailwindCSS = opts.settings.tailwindCSS or {}
            opts.settings.tailwindCSS.experimental = opts.settings.tailwindCSS.experimental or {}

            -- Look for globals.css in current directory
            local globals_css = vim.fn.getcwd() .. "/globals.css"
            if vim.fn.filereadable(globals_css) == 1 then
              -- If globals.css exists in current directory, use it
              local configFile = {}
              configFile[globals_css] = { vim.fn.getcwd() .. "/**/*" }
              opts.settings.tailwindCSS.experimental.configFile = configFile

              vim.notify(
                "Tailwind CSS using globals.css in current directory\nFull config: "
                  .. vim.inspect(opts.settings.tailwindCSS.experimental.configFile),
                vim.log.levels.INFO
              )
            else
              vim.notify("No project-specific Tailwind CSS config found.", vim.log.levels.WARN)
            end
          end
        end,
      },
    },
  },
}
