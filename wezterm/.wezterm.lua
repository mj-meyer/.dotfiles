--
-- ██╗    ██╗███████╗███████╗████████╗███████╗██████╗ ███╗   ███╗
-- ██║    ██║██╔════╝╚══███╔╝╚══██╔══╝██╔════╝██╔══██╗████╗ ████║
-- ██║ █╗ ██║█████╗    ███╔╝    ██║   █████╗  ██████╔╝██╔████╔██║
-- ██║███╗██║██╔══╝   ███╔╝     ██║   ██╔══╝  ██╔══██╗██║╚██╔╝██║
-- ╚███╔███╔╝███████╗███████╗   ██║   ███████╗██║  ██║██║ ╚═╝ ██║
--  ╚══╝╚══╝ ╚══════╝╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝
-- A GPU-accelerated cross-platform terminal emulator
-- https://wezfurlong.org/wezterm/

local dark_opacity = 0.85
local light_opacity = 0.9

local b = require("utils/background")
-- local cs = require("utils/color_scheme")
local h = require("utils/helpers")
local k = require("utils/keys")
-- local w = require("utils/wallpaper")

-- Pull in the wezterm API
local wezterm = require("wezterm")
local act = wezterm.action

-- This will hold the configuration.
-- local config = wezterm.config_builder()
local config = {
	background = {
		b.get_background(dark_opacity, light_opacity),
	},

	macos_window_background_blur = 40,
	window_background_opacity = 0.85,

	font_size = 18,
	line_height = 1.1,
	font = wezterm.font_with_fallback({
		{ family = "Operator Mono Lig", italic = true },
		{ family = "Noto Sans Symbols 2" },
		{ family = "Hack Nerd Font Mono", weight = "Regular" },
	}),
	-- For example, changing the color scheme:
	color_scheme = "Tokyo Night Moon",

	window_padding = {
		left = 20,
		right = 20,
		top = 5,
		bottom = 1,
	},

	set_environment_variables = {
		-- BAT_THEME = h.is_dark() and "Catppuccin-mocha" or "Catppuccin-latte",
		LC_ALL = "en_US.UTF-8",
		-- TODO: audit what other variables are needed
	},

	-- general options
	adjust_window_size_when_changing_font_size = false,
	debug_key_events = false,
	-- Disabled 2026-07-25: WezTerm's kitty keyboard encoding of Esc (incl. release
	-- events like CSI 27;129:3u) is dropped by herdr's input parser, making plain
	-- Esc unreliable in herdr panes. tmux/herdr provide inner-app key protocols
	-- themselves, so this only affects apps running bare in WezTerm.
	-- enable_kitty_keyboard = true,
	enable_tab_bar = false,
	native_macos_fullscreen_mode = false,
	window_close_confirmation = "NeverPrompt",
	window_decorations = "RESIZE",
	disable_default_key_bindings = true, -- Disable all default key bindings

	keys = {
		-- TODO: configure Neovim Zen Mode
		k.cmd_key(".", k.multiple_actions(":ZenMode")),

		k.cmd_key("q", k.multiple_actions(":qa!")),

		-- sesh session manager stays on a raw Ctrl+] press (tmux -n binding + zsh zle)

		-- herdr-first navigation layer: workspaces (spaces), tabs, agents, goto.
		-- All send prefix sequences; herdr/tmux intercept before the pane shell.
		k.cmd_to_tmux_prefix("j", "u"), -- space down  (herdr next_workspace; no-op in tmux)
		k.cmd_to_tmux_prefix("k", "i"), -- space up    (herdr previous_workspace; no-op in tmux)
		k.cmd_to_tmux_prefix("h", "p"), -- previous tab (tmux: previous window)
		k.cmd_to_tmux_prefix("l", "n"), -- next tab     (tmux: next window)
		k.cmd_to_tmux_prefix("g", "g"), -- herdr navigate mode (goto)
		k.cmd_to_tmux_prefix("e", "a"), -- rename tab in herdr (no-op in tmux)
		-- herdr-plus project picker (prefix+o)
		k.cmd_to_tmux_prefix("o", "o"),
		-- worktrunk worktree picker (prefix+shift+o)
		{
			mods = "CMD|SHIFT",
			key = "o",
			action = act.Multiple({
				act.SendKey({ mods = "CTRL", key = "b" }),
				act.SendKey({ mods = "SHIFT", key = "o" }),
			}),
		},
		-- herdr: close workspace (prefix+shift+d)
		{
			mods = "CMD",
			key = "d",
			action = act.Multiple({
				act.SendKey({ mods = "CTRL", key = "b" }),
				act.SendKey({ mods = "SHIFT", key = "d" }),
			}),
		},
		-- worktrunk: remove worktree, runs wt hooks (prefix+shift+r)
		{
			mods = "CMD|SHIFT",
			key = "d",
			action = act.Multiple({
				act.SendKey({ mods = "CTRL", key = "b" }),
				act.SendKey({ mods = "SHIFT", key = "r" }),
			}),
		},
		{
			mods = "CMD|SHIFT",
			key = "e",
			action = act.Multiple({
				act.SendKey({ mods = "CTRL", key = "b" }),
				act.SendKey({ mods = "SHIFT", key = "w" }),
			}),
		}, -- rename workspace in herdr (no-op in tmux)
		k.cmd_to_tmux_prefix("w", "&"), -- close tab (tmux: kill-window w/ confirm)
		k.cmd_to_tmux_prefix("x", "x"), -- close pane (tmux: kill-pane)
		{
			mods = "CMD|ALT",
			key = "j",
			action = act.Multiple({
				act.SendKey({ mods = "CTRL", key = "b" }),
				act.SendKey({ mods = "SHIFT", key = "j" }),
			}),
		},
		{
			mods = "CMD|ALT",
			key = "k",
			action = act.Multiple({
				act.SendKey({ mods = "CTRL", key = "b" }),
				act.SendKey({ mods = "SHIFT", key = "k" }),
			}),
		},
		-- new window
		k.cmd_to_tmux_prefix("t", "c"),
		-- Send Alt+T to terminal (for Claude Code thinking mode)
		{
			mods = "CMD|SHIFT",
			key = "t",
			action = act.SendString("\x1bt"),
		},
		k.cmd_to_tmux_prefix("r", "r"),
		k.cmd_to_tmux_prefix("y", "{"),

		-- nav windows by number
		k.cmd_to_tmux_prefix("1", "1"),
		k.cmd_to_tmux_prefix("2", "2"),
		k.cmd_to_tmux_prefix("3", "3"),
		k.cmd_to_tmux_prefix("4", "4"),
		k.cmd_to_tmux_prefix("5", "5"),
		k.cmd_to_tmux_prefix("6", "6"),
		k.cmd_to_tmux_prefix("7", "7"),
		k.cmd_to_tmux_prefix("8", "8"),
		k.cmd_to_tmux_prefix("9", "9"),

		-- save neovim
		k.cmd_key(
			"s",
			act.Multiple({
				act.SendKey({ key = "\x1b" }), -- escape
				k.multiple_actions(":w"),
			})
		),

		{
			mods = "CTRL|SHIFT",
			key = "h",
			action = act.Multiple({
				act.SendKey({ mods = "CTRL", key = "b" }),
				act.SendKey({ key = "h" }),
			}),
		},
		{
			mods = "CTRL|SHIFT",
			key = "l",
			action = act.Multiple({
				act.SendKey({ mods = "CTRL", key = "b" }),
				act.SendKey({ key = "l" }),
			}),
		},
		{
			mods = "CTRL|SHIFT",
			key = "j",
			action = act.Multiple({
				act.SendKey({ mods = "CTRL", key = "b" }),
				act.SendKey({ key = "j" }),
			}),
		},
		{
			mods = "CTRL|SHIFT",
			key = "k",
			action = act.Multiple({
				act.SendKey({ mods = "CTRL", key = "b" }),
				act.SendKey({ key = "k" }),
			}),
		},
		{
			mods = "CMD",
			key = "N",
			action = act.Multiple({
				act.SendKey({ mods = "CTRL", key = "b" }),
				act.SendKey({ key = "-" }),
			}),
		},
		{
			mods = "CMD",
			key = "n",
			action = act.Multiple({
				act.SendKey({ mods = "CTRL", key = "b" }),
				act.SendKey({ key = "\\" }),
			}),
		},
		{
			mods = "CMD",
			key = "z",
			action = act.Multiple({
				act.SendKey({ mods = "CTRL", key = "b" }),
				act.SendKey({ key = "z" }),
			}),
		},

		{
			mods = "CMD|SHIFT",
			key = "}",
			action = act.Multiple({
				act.SendKey({ mods = "CTRL", key = "b" }),
				act.SendKey({ key = "n" }),
			}),
		},
		{
			mods = "CMD|SHIFT",
			key = "{",
			action = act.Multiple({
				act.SendKey({ mods = "CTRL", key = "b" }),
				act.SendKey({ key = "p" }),
			}),
		},

		{
			mods = "CTRL",
			key = "Tab",
			action = act.Multiple({
				act.SendKey({ mods = "CTRL", key = "b" }),
				act.SendKey({ key = "n" }),
			}),
		},
		-- reload tmux
		k.cmd_key(
			"R",
			act.Multiple({
				act.SendKey({ key = "\x1b" }), -- escape
				k.multiple_actions(":source %"),
			})
		),

		-- Reimplementation of wezterm defaults
		--
		-- Copy to clipboard
		{
			mods = "SUPER",
			key = "c",
			action = act.CopyTo("Clipboard"),
		},
		-- Paste from clipboard
		{
			mods = "SUPER",
			key = "v",
			action = act.PasteFrom("Clipboard"),
		},
		-- Send Ctrl+V to terminal (for Claude Code image paste)
		{
			mods = "CMD|SHIFT",
			key = "v",
			action = act.SendString("\x16"),
		},
		-- Copy to clipboard using Ctrl+Shift+C (alternative for Linux-like behavior)
		{
			mods = "CTRL|SHIFT",
			key = "C",
			action = act.CopyTo("Clipboard"),
		},
		-- Paste from clipboard using Ctrl+Shift+V (alternative for Linux-like behavior)
		{
			mods = "CTRL|SHIFT",
			key = "V",
			action = act.PasteFrom("Clipboard"),
		},
		-- Close the current tab
		{
			mods = "CMD|ALT",
			key = "q",
			action = act.CloseCurrentTab({ confirm = false }),
		},
		-- Set tmux pane title/label (CMD+SHIFT+l -> prefix+L; CMD+l is next tab)
		{
			mods = "CMD|SHIFT",
			key = "l",
			action = act.Multiple({
				act.SendKey({ mods = "CTRL", key = "b" }),
				act.SendKey({ mods = "SHIFT", key = "l" }),
			}),
		},
	},
}

return config
