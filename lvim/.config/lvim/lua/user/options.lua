local opt = vim.opt

-- General
lvim.log.level = "warn"
lvim.format_on_save = true
lvim.colorscheme = "tokyonight"
lvim.transparent_window = true

-- NvimTree
lvim.builtin.nvimtree.setup.view.float.enable = true
lvim.builtin.nvimtree.setup.filters.custom = {}
-- Float Nvimtree in middle of the screen
local HEIGHT_RATIO = 0.8
local WIDTH_RATIO = 0.8
lvim.builtin.nvimtree.setup.view.float.open_win_config = function()
  local screen_w = vim.opt.columns:get()
  local screen_h = vim.opt.lines:get() - vim.opt.cmdheight:get()
  local window_w = screen_w * WIDTH_RATIO
  local window_h = screen_h * HEIGHT_RATIO
  local window_w_int = math.floor(window_w)
  local window_h_int = math.floor(window_h)
  local center_x = (screen_w - window_w) / 2
  local center_y = ((vim.opt.lines:get() - window_h) / 2) - vim.opt.cmdheight:get()
  return {
    border = 'rounded',
    relative = 'editor',
    row = center_y,
    col = center_x,
    width = window_w_int,
    height = window_h_int,
  }
end
lvim.builtin.nvimtree.setup.view.width = function()
  return math.floor(vim.opt.columns:get() * WIDTH_RATIO)
end

-- Vim options
opt.foldmethod = "expr"
opt.foldexpr = "nvim_treesitter#foldexpr()"
opt.foldlevel = 99
opt.relativenumber = true
opt.guifont = { "Operator Mono Lig, FuraMono Nerd Font Mono", ":h16" }

-- Neovide options
vim.g.neovide_scale_factor = 2.0
vim.g.neovide_transparency = 0.9
vim.g.neovide_input_use_logo = 1

-- Other LunarVim options
lvim.builtin.alpha.active = true
lvim.builtin.alpha.mode = "dashboard"
lvim.builtin.terminal.active = true
-- lvim.builtin.nvimtree.setup.view.side = "left"
lvim.builtin.nvimtree.setup.renderer.icons.show.git = false
lvim.builtin.nvimtree.setup.filters.dotfiles = false
