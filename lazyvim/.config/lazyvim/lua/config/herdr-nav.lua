-- vim-herdr-navigation (editor side): move between Neovim splits, and at a
-- split edge hand off to herdr so focus crosses into the neighbouring herdr
-- pane. Outside herdr it falls back to tmux (if any) or stays put.
-- Mapped in config/keymaps.lua, which must own these keys: LazyVim applies its
-- default <C-h/j/k/l> window maps on VeryLazy, after any after/plugin file.
local M = {}

local function nav(wincmd, dir)
  local prev = vim.api.nvim_get_current_win()
  vim.cmd("wincmd " .. wincmd)
  if vim.api.nvim_get_current_win() ~= prev then
    return -- moved within Neovim
  end
  -- At a split edge: cross into the surrounding multiplexer.
  if vim.env.HERDR_PANE_ID and vim.env.HERDR_PANE_ID ~= "" then
    local herdr = vim.env.HERDR_BIN_PATH
    if herdr == nil or herdr == "" then
      herdr = "herdr"
    end
    vim.fn.system({ herdr, "pane", "focus", "--direction", dir, "--current" })
  elseif vim.env.TMUX and vim.env.TMUX ~= "" then
    local tmux = { left = "Left", down = "Down", up = "Up", right = "Right" }
    pcall(vim.cmd, "TmuxNavigate" .. tmux[dir])
  end
end

function M.left()
  nav("h", "left")
end

function M.down()
  nav("j", "down")
end

function M.up()
  nav("k", "up")
end

function M.right()
  nav("l", "right")
end

return M
