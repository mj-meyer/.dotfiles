lvim.plugins = {
  { "folke/trouble.nvim",            cmd = "TroubleToggle" },
  {
    "zbirenbaum/copilot.lua",
    event = { "VimEnter" },
    config = function()
      vim.defer_fn(function()
        require("copilot").setup {
          plugin_manager_path = get_runtime_dir() .. "/site/pack/packer",
          suggestion = { auto_trigger = true }
        }
      end, 100)
    end,
  },
  { "zbirenbaum/copilot-cmp",        after = { "copilot.lua", "nvim-cmp" } },
  { "tpope/vim-surround" },
  { "tpope/vim-repeat" },
  { "elianiva/telescope-npm.nvim" },
  { "vim-test/vim-test" },
  { "christoomey/vim-tmux-navigator" },
  { "wuelnerdotexe/vim-astro" },
  {
    "ruifm/gitlinker.nvim",
    event = "BufRead",
    config = function()
      require("gitlinker").setup {
        opts = {
          add_current_line_on_normal_mode = true,
          action_callback = require("gitlinker.actions").open_in_browser,
          print_url = false,
          mappings = "<leader>gy",
        },
      }
    end,
    dependencies = "nvim-lua/plenary.nvim",
  },
  {
    "windwp/nvim-ts-autotag",
    config = function()
      require("nvim-ts-autotag").setup()
    end,
  },
  {
    "romgrk/nvim-treesitter-context",
    config = function()
      require("treesitter-context").setup {
        enable = true,
        throttle = true,
        max_lines = 0,
        patterns = {
          default = {
            'class',
            'function',
            'method',
          },
        },
      }
    end
  },
  {
    "rmagatti/goto-preview",
    config = function()
      require('goto-preview').setup {
        width = 120,
        height = 25,
        default_mappings = true,
        debug = false,
        opacity = nil,
        post_open_hook = nil,
      }
    end
  },
  {
    "folke/todo-comments.nvim",
    event = "BufRead",
    config = function()
      require("todo-comments").setup()
    end,
  },
  {
    "kevinhwang91/nvim-bqf",
    event = { "BufRead", "BufNew" },
    config = function()
      require("bqf").setup({
        auto_enable = true,
        preview = {
          win_height = 12,
          win_vheight = 12,
          delay_syntax = 80,
          border_chars = { "┃", "┃", "━", "━", "┏", "┓", "┗", "┛", "█" },
        },
        func_map = {
          vsplit = "",
          ptogglemode = "z,",
          stoggleup = "",
        },
        filter = {
          fzf = {
            action_for = { ["ctrl-s"] = "split" },
            extra_opts = { "--bind", "ctrl-o:toggle-all", "--prompt", "> " },
          },
        },
      })
    end,
  },
  { "mg979/vim-visual-multi" },
  { "ThePrimeagen/harpoon" },
  { "mxsdev/nvim-dap-vscode-js" },
  {
    "tpope/vim-fugitive",
    cmd = {
      "G", "Git", "Gdiffsplit", "Gread", "Gwrite", "Ggrep", "GMove",
      "GDelete", "GBrowse", "GRemove", "GRename", "Glgrep", "Gedit"
    },
    ft = { "fugitive" }
  },
  { "shumphrey/fugitive-gitlab.vim" },
  -- {
  --   "harrisoncramer/gitlab.nvim",
  --   dependencies = {
  --     "MunifTanjim/nui.nvim",
  --     "nvim-lua/plenary.nvim",
  --     "sindrets/diffview.nvim",
  --     "stevearc/dressing.nvim",
  --     "nvim-tree/nvim-web-devicons"
  --   },
  --   enabled = true,
  --   build = function() require("gitlab.server").build(true) end,
  --   config = function()
  --     require("gitlab").setup({
  --       log_path = vim.fn.stdpath("cache") .. "/gitlab.nvim.log", -- Log path for the Go server
  --       debug = { go_request = true, go_response = true }, -- Which values to log
  --       reviewer_settings = {
  --         diffview = {
  --           imply_local = true, -- If true, will attempt to use --imply_local option when calling |:DiffviewOpen|
  --         },
  --       },
  --       connection_settings = {
  --         insecure = true, -- Like curl's --insecure option, ignore bad x509 certificates on connection
  --       },
  --     })
  --   end,
  -- },
  {
    enabled = false,
    "antosha417/nvim-lsp-file-operations",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "kyazdani42/nvim-tree.lua",
    },
    config = function()
      require("lsp-file-operations").setup()
    end,
  },
  { 'wakatime/vim-wakatime',        lazy = false },
  -- {
  --   "dreamsofcode-io/ChatGPT.nvim",
  --   event = "VeryLazy",
  --   config = function()
  --     require("chatgpt").setup({
  --       async_api_key_cmd = "pass show openai/neovim",
  --     })
  --   end,
  --   dependencies = {
  --     "MunifTanjim/nui.nvim",
  --     "nvim-lua/plenary.nvim",
  --     "folke/trouble.nvim",
  --     "nvim-telescope/telescope.nvim"
  --   }
  -- },
  -- {
  --   url = 'https://gitlab.com/itaranto/plantuml.nvim',
  --   config = function()
  --     require('plantuml').setup({
  --       renderer = {
  --         type = 'image',
  --         options = {
  --           prog = 'open -a Preview',
  --         }
  --       },
  --       render_on_write = true,
  --     })
  --   end,
  -- },
}

-- LuaSnip configuration
require("luasnip/loaders/from_vscode").load { paths = {
  "~/.dotfiles/lvim/.config/lvim/snippets/vscode-es7-javascript-react-snippets" } }
require("luasnip/loaders/from_vscode").load { paths = { "~/.dotfiles/lvim/.config/lvim/snippets/mj-snippets" } }

-- Telescope configuration
local status_ok, telescope = pcall(require, "telescope")
if status_ok then
  local h_status_ok, harpoon = pcall(require, "harpoon")
  if h_status_ok then
    telescope.load_extension "harpoon"
  end
end

-- Copilot configuration
lvim.builtin.cmp.formatting.source_names["copilot"] = "(Copilot)"
table.insert(lvim.builtin.cmp.sources, 1, { name = "copilot" })
