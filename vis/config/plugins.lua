local fm = require('plugins/fm')
require('plugins/autoclose')
require('plugins/complete-filename')

local colorizer = require('plugins/colorizer')
colorizer.three = true
colorizer.six = true

local lspc = require('plugins/lspc')

lspc.key_filter = function(mode, key)
	if not fm.active() then return true end
	if mode == vis.modes.NORMAL then fm.handle_key(key) end
	return false
end
lspc.ls_map.python.roots = {
	'pyproject.toml', 'requirements.txt', 'setup.py', 'setup.cfg',
}

local deno = {
	name = 'deno',
	cmd = 'deno lsp',
	roots = {'deno.json', 'deno.jsonc', 'package.json', 'tsconfig.json', 'jsconfig.json'},
	init_options = {enable = true, lint = true},
	settings = {deno = {enable = true, lint = true}},
	formatting_options = {tabSize = 4, insertSpaces = false},
}
lspc.ls_map.javascript = deno
lspc.ls_map.typescript = deno

return { fm = fm }
