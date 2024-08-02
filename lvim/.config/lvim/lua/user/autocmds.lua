local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- Autocommands (https://neovim.io/doc/user/autocmd.html)
local myAutoGroup = augroup("myAutoGroup", {})

-- Uncomment the following to enable wrap mode for json files
-- autocmd("BufEnter", {
--   pattern = { "*.json", "*.jsonc" },
--   command = "setlocal wrap",
--   group = myAutoGroup,
-- })

-- Uncomment the following to use bash highlight for zsh files
-- autocmd("FileType", {
--   pattern = "zsh",
--   callback = function()
--     -- let treesitter use bash highlight for zsh files as well
--     require("nvim-treesitter.highlight").attach(0, "bash")
--   end,
--   group = myAutoGroup,
-- })

-- Add any other autocommands here
