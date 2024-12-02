local opts = { noremap = true, silent = true }

-- General keymaps
lvim.leader = "space"
lvim.keys.normal_mode["<C-s>"] = ":w<cr>"
lvim.keys.normal_mode["<S-l>"] = ":BufferLineCycleNext<CR>"
lvim.keys.normal_mode["<S-h>"] = ":BufferLineCyclePrev<CR>"

-- Clipboard keymaps for Neovide
vim.api.nvim_set_keymap('', '<D-v>', '+p<CR>', opts)
vim.api.nvim_set_keymap('!', '<D-v>', '<C-R>+', opts)
vim.api.nvim_set_keymap('t', '<D-v>', '<C-R>+', opts)
vim.api.nvim_set_keymap('v', '<D-v>', '<C-R>+', opts)

-- Escape from insert mode
vim.api.nvim_set_keymap('i', 'jk', '<ESC>', opts)
vim.api.nvim_set_keymap('i', 'kj', '<ESC>', opts)

-- LSP formatting in visual mode
vim.api.nvim_set_keymap('v', '<leader>lf', '<cmd>lua vim.lsp.buf.format()<CR>', opts)

-- Which-key mappings
lvim.builtin.which_key.mappings["t"] = {
  name = "+Trouble",
  r = { "<cmd>Trouble lsp_references<cr>", "References" },
  f = { "<cmd>Trouble lsp_definitions<cr>", "Definitions" },
  d = { "<cmd>Trouble document_diagnostics<cr>", "Diagnostics" },
  q = { "<cmd>Trouble quickfix<cr>", "QuickFix" },
  l = { "<cmd>Trouble loclist<cr>", "LocationList" },
  w = { "<cmd>Trouble workspace_diagnostics<cr>", "Workspace Diagnostics" },
}

lvim.builtin.which_key.mappings["n"] = {
  name = "+NPM",
  s = { "<cmd>Telescope npm scripts<cr>", "Scripts" },
  d = { "<cmd>Telescope npm packages<cr>", "Packages" },
}

lvim.builtin.which_key.mappings["r"] = {
  name = "+Review (Gitlab)",
  c = { '<cmd>lua require("gitlab").choose_merge_request()<cr>', 'Choose MR' },
  r = { '<cmd>lua require("gitlab.server").restart()<cr>', 'Restart Server' },
}


lvim.builtin.which_key.mappings["h"] = {
  name = "+Harpoon",
  h = { '<cmd>lua require("harpoon.mark").add_file()<cr>', "Harpoon" },
  ["."] = { '<cmd>lua require("harpoon.ui").nav_next()<cr>', "Harpoon Next" },
  [","] = { '<cmd>lua require("harpoon.ui").nav_prev()<cr>', "Harpoon Prev" },
  s = { "<cmd>Telescope harpoon marks<cr>", "Search Files" },
  [";"] = { '<cmd>lua require("harpoon.ui").toggle_quick_menu()<cr>', "Harpoon UI" },
}

lvim.builtin.which_key.mappings["v"] = {
  name = "+Vsplit",
  v = { "<cmd>vsplit | lua vim.lsp.buf.definition()<CR>", "Vsplit" },
}

-- -- ChatGPT keymaps
-- lvim.builtin.which_key.mappings["a"] = {
--   name = "+ChatGPT",
--   c = { "<cmd>ChatGPT<CR>", "ChatGPT" },
--   e = { "<cmd>ChatGPTEditWithInstruction<CR>", "Edit with instruction", mode = { "n", "v" } },
--   g = { "<cmd>ChatGPTRun grammar_correction<CR>", "Grammar Correction", mode = { "n", "v" } },
--   t = { "<cmd>ChatGPTRun translate<CR>", "Translate", mode = { "n", "v" } },
--   k = { "<cmd>ChatGPTRun keywords<CR>", "Keywords", mode = { "n", "v" } },
--   d = { "<cmd>ChatGPTRun docstring<CR>", "Docstring", mode = { "n", "v" } },
--   a = { "<cmd>ChatGPTRun add_tests<CR>", "Add Tests", mode = { "n", "v" } },
--   o = { "<cmd>ChatGPTRun optimize_code<CR>", "Optimize Code", mode = { "n", "v" } },
--   s = { "<cmd>ChatGPTRun summarize<CR>", "Summarize", mode = { "n", "v" } },
--   f = { "<cmd>ChatGPTRun fix_bugs<CR>", "Fix Bugs", mode = { "n", "v" } },
--   x = { "<cmd>ChatGPTRun explain_code<CR>", "Explain Code", mode = { "n", "v" } },
--   r = { "<cmd>ChatGPTRun roxygen_edit<CR>", "Roxygen Edit", mode = { "n", "v" } },
--   l = { "<cmd>ChatGPTRun code_readability_analysis<CR>", "Code Readability Analysis", mode = { "n", "v" } },
-- }
