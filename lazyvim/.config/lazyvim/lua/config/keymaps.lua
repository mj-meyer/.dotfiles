-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Tmux Navigate Windows
vim.keymap.set("n", "<C-h>", "<Cmd>TmuxNavigateLeft<CR>", {})
vim.keymap.set("n", "<C-j>", "<Cmd>TmuxNavigateDown<CR>", {})
vim.keymap.set("n", "<C-k>", "<Cmd>TmuxNavigateUp<CR>", {})
vim.keymap.set("n", "<C-l>", "<Cmd>TmuxNavigateRight<CR>", {})

-- Escape from insert mode
vim.keymap.set("i", "jk", "<ESC>", {})
vim.keymap.set("i", "kj", "<ESC>", {})

-- Normal mode: Move the current line
vim.keymap.set("n", "<C-M-k>", ":m .-2<CR>==", { noremap = true, silent = true })
vim.keymap.set("n", "<C-M-j>", ":m .+1<CR>==", { noremap = true, silent = true })

-- Visual mode: Move the selected block
vim.keymap.set("v", "<C-M-k>", ":m '<-2<CR>gv=gv", { noremap = true, silent = true })
vim.keymap.set("v", "<C-M-j>", ":m '>+1<CR>gv=gv", { noremap = true, silent = true })
