require('vis')

local plugins = require('config/plugins')
local statusline = require('config/statusline')
local native_syntax = { ansi_c = true, cpp = true, markdown = true }

vis.events.subscribe(vis.events.INIT, function()
	vis:command("set theme modus_vivendi")
	vis:command("set shell /bin/sh")
end)

vis.events.subscribe(vis.events.WIN_OPEN, function(win)
	vis:command("set tabwidth 4")
	vis:command("set number")
	vis:command("set relativenumbers")
	vis:command("set autoindent")
	vis:command("set showtabs")

	-- Use Bash highlighting outside the native syntax list.
	if not plugins.fm.active(win) and not native_syntax[win.syntax] then
		win.syntax = 'bash'
	end
end)

vis:map(vis.modes.VISUAL, " y", '"+y')

vis.events.subscribe(vis.events.WIN_STATUS, function(win)
	statusline(win, plugins.fm)
end)
