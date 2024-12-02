-- Formatters configuration
local formatters = require "lvim.lsp.null-ls.formatters"
formatters.setup {
  {
    command = "prettier",
    filetypes = { "javascript", "typescript", "typescriptreact", "css", "scss", "html", "json", "yaml", "markdown",
      "graphql", "md", "txt", "astro", },
  }
}

-- Linters configuration
local linters = require "lvim.lsp.null-ls.linters"
linters.setup {
  {
    command = "eslint_d",
    filetypes = { "typescript", "typescriptreact", "javascript", "javascriptreact", "vue", "svelte", "astro" }
  },
}

-- CSS Language Server configuration
require("lvim.lsp.manager").setup("cssls", {
  settings = {
    css = {
      validate = true,
      lint = {
        unkownAtRules = "ignore",
      }
    },
    scss = {
      validate = true,
      lint = {
        unkownAtRules = "ignore",
      }
    },
  }
})

-- Gleam Language Server configuration
vim.list_extend(lvim.lsp.automatic_configuration.skipped_servers, { "gleam" })

local common_opts = require("lvim/lsp").get_common_opts()
local util = require("lspconfig/util")
local lspconfig = require("lspconfig")

local gleam_opts = {
  cmd = { 'gleam', 'lsp' },
  filetypes = { 'gleam' },
  root_dir = util.root_pattern('gleam.toml', '.git'),
}

lspconfig.gleam.setup(vim.tbl_extend("force", gleam_opts, common_opts))

-- Debug Adapter configuration
require("dap-vscode-js").setup {
  debugger_path = vim.fn.expand("~") .. "/vscode-js-debug",
  adapters = { "pwa-node", "pwa-chrome", "pwa-msedge", "node-terminal", "pwa-extensionHost" },
}

for _, language in ipairs { "typescript", "javascript", "typescriptreact" } do
  require("dap").configurations[language] = {
    {
      type = "pwa-node",
      request = "launch",
      name = "Debug Jest Tests",
      runtimeExecutable = "node",
      runtimeArgs = {
        "./node_modules/jest/bin/jest.js",
        "--runInBand",
      },
      rootPath = "${workspaceFolder}",
      cwd = "${workspaceFolder}",
      console = "integratedTerminal",
      internalConsoleOptions = "neverOpen",
    },
    {
      type = "pwa-chrome",
      name = "Launch Chrome to debug client",
      request = "launch",
      url = "http://localhost:3001",
      sourceMaps = true,
      protocol = "inspector",
      port = 9222,
      webRoot = "${workspaceFolder}/src",
      -- skip files from vite's hmr
      skipFiles = { "**/node_modules/**/*", "**/@vite/*", "**/src/client/*", "**/src/*" },
    },
  }
end

-- Treesitter configuration
lvim.builtin.treesitter.ensure_installed = {
  "bash",
  "c",
  "javascript",
  "json",
  "lua",
  "python",
  "typescript",
  "tsx",
  "css",
  "rust",
  "java",
  "yaml",
  "astro",
}

lvim.builtin.treesitter.ignore_install = { "haskell" }
lvim.builtin.treesitter.highlight.enable = true
