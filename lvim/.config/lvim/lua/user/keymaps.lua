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
