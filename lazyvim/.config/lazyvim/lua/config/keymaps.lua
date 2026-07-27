-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Navigate windows + herdr/tmux panes (falls back to TmuxNavigate* in tmux)
local nav = require("config.herdr-nav")
vim.keymap.set("n", "<C-h>", nav.left, { desc = "Navigate left (vim/herdr)" })
vim.keymap.set("n", "<C-j>", nav.down, { desc = "Navigate down (vim/herdr)" })
vim.keymap.set("n", "<C-k>", nav.up, { desc = "Navigate up (vim/herdr)" })
vim.keymap.set("n", "<C-l>", nav.right, { desc = "Navigate right (vim/herdr)" })

-- Escape from insert mode
vim.keymap.set("i", "jk", "<ESC>", {})
vim.keymap.set("i", "kj", "<ESC>", {})

-- Normal mode: Move the current line
vim.keymap.set("n", "<C-M-k>", ":m .-2<CR>==", { noremap = true, silent = true })
vim.keymap.set("n", "<C-M-j>", ":m .+1<CR>==", { noremap = true, silent = true })

-- Visual mode: Move the selected block
vim.keymap.set("v", "<C-M-k>", ":m '<-2<CR>gv=gv", { noremap = true, silent = true })
vim.keymap.set("v", "<C-M-j>", ":m '>+1<CR>gv=gv", { noremap = true, silent = true })
