require('vis')

-- the best config possible don't you dare insult

require('config/plugins')
local statusline = require('config/statusline')

vis.events.subscribe(vis.events.INIT, function()
	vis:command("set theme modus_vivendi")
	vis:command("set shell /bin/sh")
end)

-- emacs influence with the modus vivendi :)

vis.events.subscribe(vis.events.WIN_OPEN, function()
	vis:command("set tabwidth 4")
	vis:command("set number")
	vis:command("set relativenumbers")
	vis:command("set autoindent")
	vis:command("set showtabs")
end)

vis:map(vis.modes.VISUAL, " y", '"+y')

vis.events.subscribe(vis.events.WIN_STATUS, statusline)
