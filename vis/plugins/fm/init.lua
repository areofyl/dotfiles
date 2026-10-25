-- vis-fm: a dired-style file browser with editable rename listings.
local fs = require('plugins/fm/fs')
local rename = require('plugins/fm/rename')
local esc, run, output = fs.esc, fs.run, fs.output
local M = {}

-- Each browser buffer owns its directory, rename baseline and return file.
local sessions = {}
local cursor_memory = {}

local function session(win)
	win = win or vis.win
	return win and win.file and (sessions[win.file.path] or sessions[win.file.name])
end

function M.active(win)
	return session(win) ~= nil
end

local function pending_edits()
	if M.active() and vis.win.file.modified then
		vis:info('Unsaved rename edits — :w to apply, :e! to discard')
		return true
	end
	return false
end

local function can_refresh(file)
	local count = 0
	for win in vis:windows() do
		if win.file == file then count = count + 1 end
	end
	if count > 1 then
		vis:info('Close the duplicate view of this listing, or open a separate browser')
		return false
	end
	return true
end

local function vis_path(path)
	return '"' .. path:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
end

-- Strip only the line terminator; spaces in filenames are significant.
local function entry_name(line)
	return line and line:gsub('\n$', '')
end

local function get_line()
	return vis.win and entry_name(vis.win.file.lines[vis.win.selection.line])
end

local function scan(s)
	local flags = s.show_hidden and '-1ApL' or '-1pL'
	local sort = s.sort_mode == 'name' and '' or ' --sort=' .. s.sort_mode
	local command = 'ls ' .. flags .. sort .. ' --zero -- ' .. esc(s.dir)
	local pipe = io.popen(command .. ' 2>/dev/null')
	if not pipe then return nil, 'Cannot read directory: ' .. s.dir end
	local data = pipe:read('*a')
	local ok = pipe:close()
	local warning
	if ok ~= true and ok ~= 0 and data == '' then
		return nil, 'Cannot list directory (check permissions and GNU ls --zero): ' .. s.dir
	elseif ok ~= true and ok ~= 0 then
		warning = 'Some entries could not be inspected (for example, broken symlinks): ' .. s.dir
	end
	local entries = {'..'}
	for name in data:gmatch('([^%z]+)%z') do
		if name:find('\n', 1, true) then
			return nil, 'Cannot list this directory: a filename contains a newline'
		end
		entries[#entries + 1] = name
	end
	return entries, warning
end

local function refresh(s, entries)
	if session() == s and not can_refresh(vis.win.file) then return false end
	local message
	if not entries then entries, message = scan(s) end
	if not entries then vis:info(message); return false end
	local file = io.open(s.path, 'w')
	if not file then vis:info('Cannot write browser listing'); return false end
	local written = file:write(table.concat(entries, '\n') .. '\n')
	local closed = file:close()
	if not written or not closed then
		vis:info('Cannot write browser listing')
		return false
	end
	if session() == s then
		vis:command('e!')
	else
		vis:command('e ' .. vis_path(s.path))
	end
	if session() ~= s then return false end
	s.original = entries
	local target = cursor_memory[s.dir]
	for i, name in ipairs(entries) do
		if name == target then vis.win.selection:to(i, 1); return true end
	end
	vis.win.selection:to(#entries > 1 and 2 or 1, 1)
	return true
end

function M.open(directory)
	if not vis.win or pending_edits() then return false end
	if M.active() and not can_refresh(vis.win.file) then return false end
	if directory:find('\n', 1, true) then
		vis:info('Cannot browse a directory whose path contains a newline')
		return false
	end
	local resolved = output('realpath -- ' .. esc(directory) .. ' 2>/dev/null')
	if not resolved then vis:info('Cannot resolve directory: ' .. directory); return false end
	if resolved:find('\n', 1, true) then
		vis:info('Cannot browse a directory whose path contains a newline')
		return false
	end
	if not run('test -d ' .. esc(resolved)) then
		vis:info('Not a directory: ' .. directory)
		return false
	end
	local s = session()
	local previous_dir
	if s then previous_dir = s.dir end
	local fresh = not s
	if fresh then
		local previous = vis.win.file.name
		if previous then previous = output('realpath -ms -- ' .. esc(previous)) or previous end
		s = {path = os.tmpname(), prev_file = previous,
			show_hidden = true, sort_mode = 'time', original = {}}
	end
	s.dir = resolved
	local entries, message = scan(s)
	if not entries then
		s.dir = previous_dir
		if fresh then os.remove(s.path) end
		vis:info(message)
		return false
	end
	if fresh then sessions[s.path] = s end
	if not refresh(s, entries) then
		s.dir = previous_dir
		if fresh then sessions[s.path] = nil; os.remove(s.path) end
		return false
	end
	if message then vis:info(message) end
	return true
end

local function up()
	local s = session()
	local parent = s.dir:match('(.+)/[^/]+$') or '/'
	local name = s.dir:match('([^/]+)$')
	if name then cursor_memory[parent] = name .. '/' end
	M.open(parent)
end

local function enter()
	local s, name = session(), get_line()
	if not name or name == '' then return end
	if name == '..' then up(); return end
	cursor_memory[s.dir] = name
	local path = s.dir .. '/' .. name:gsub('/$', '')
	if run('test -d ' .. esc(path)) then
		M.open(path)
	else
		local encoding = output('file -L --brief --mime-encoding -- ' .. esc(path))
		if not encoding then vis:info('Cannot inspect file: ' .. path); return end
		local mime = encoding == 'binary'
			and output('file -L --brief --mime-type -- ' .. esc(path))
		if encoding == 'binary' and mime ~= 'inode/x-empty' and mime ~= 'application/x-empty' then
			os.execute('xdg-open ' .. esc(path) .. ' >/dev/null 2>&1 &')
		else
			vis:command('e ' .. vis_path(path))
		end
	end
end

local function close_browser(keep_editor)
	if pending_edits() then return end
	local s = session()
	cursor_memory[s.dir] = get_line()
	if s.prev_file then
		vis:command('e ' .. vis_path(s.prev_file))
	elseif keep_editor then
		local browser = vis.win
		vis:command('new')
		if vis.win ~= browser then browser:close() end
	else
		vis:command('q!')
	end
end

local bindings = {}
function M.handle_key(key)
	if not M.active() or not bindings[key] then return end
	if key ~= 'g?' and pending_edits() then return true end
	if key ~= 'g?' and key ~= 'q' and not can_refresh(vis.win.file) then return true end
	bindings[key]()
	return true
end

local function map(key, action)
	bindings[key] = action
	vis:map(vis.modes.NORMAL, key, function() return M.handle_key(key) end)
end

map('<Enter>', enter)
map('-', up)
map('q', function() close_browser(false) end)
map('gh', function()
	local s = session()
	s.show_hidden = not s.show_hidden
	if not refresh(s) then s.show_hidden = not s.show_hidden end
end)
map('gs', function()
	local s = session()
	local previous = s.sort_mode
	s.sort_mode = ({time = 'size', size = 'name', name = 'time'})[previous]
	if not refresh(s) then s.sort_mode = previous end
end)
local function prompt_create() vis:feedkeys(':fma ') end
map('o', prompt_create)
map('ga', prompt_create)
map('gd', function()
	local name = get_line()
	if name and name ~= '..' and name ~= '' then
		vis:info('Delete ' .. name .. '? Run :fmd! to confirm')
	end
end)
map('dd', function() vis:command('fmd!') end)
map('g?', function()
	vis:info('fm: <Space>e=toggle  <CR>=open  -=up  q=quit  gh=hidden  gs=sort  o/ga=new (dir: / suffix)  dd=trash  gd=del help  :w=rename  g?=help')
end)

function M.toggle()
	if M.active() then close_browser(true); return end
	local name = vis.win and vis.win.file and vis.win.file.name
	M.open(name and name:match('(.+)/[^/]+$') or '.')
end
vis:map(vis.modes.NORMAL, ' e', M.toggle, 'Toggle file browser')

vis:command_register('fma', function(argv)
	local s = session()
	if not s or pending_edits() then return true end
	if not can_refresh(vis.win.file) then return true end
	if #argv == 0 then vis:info('Usage: :fma <name> (end with / for directory)'); return true end
	local name = table.concat(argv, ' ')
	if name == '' or name:find('\n', 1, true) then
		vis:info('Use a nonempty name without newlines'); return true
	end
	local path = s.dir .. '/' .. name
	local target = path:gsub('/+$', '')
	if fs.exists(target) then vis:info('Already exists: ' .. name); return true end
	local ok
	if name:match('/$') then
		ok = run('mkdir -p -- ' .. esc(target))
	else
		local parent = path:match('(.+)/[^/]+$')
		ok = run('mkdir -p -- ' .. esc(parent) .. ' && (set -C; : > ' .. esc(path) .. ')')
	end
	if not ok then vis:info('Failed to create: ' .. name) end
	refresh(s)
	return true
end, 'Create file or directory (/ suffix for dir)')

vis:command_register('fmd', function(_, force)
	local s = session()
	if not s or pending_edits() then return true end
	if not can_refresh(vis.win.file) then return true end
	local name = get_line()
	if not name or name == '..' or name == '' then return true end
	if not force then vis:info('Delete ' .. name .. '? Use :fmd! to confirm'); return true end
	local path = s.dir .. '/' .. name:gsub('/$', '')
	vis:info(fs.trash(path) and 'Trashed ' .. name or 'Failed to trash: ' .. name)
	refresh(s)
	return true
end, 'Trash entry under cursor (use ! to confirm)')

vis.events.subscribe(vis.events.FILE_SAVE_PRE, function(file, path)
	local s = sessions[path] or (path == file.name and sessions[file.path])
	if not s then return end
	if not can_refresh(file) then return false end
	s.refresh_after_save = nil
	local names = {}
	for i = 1, #file.lines do
		local name = entry_name(file.lines[i])
		if name and name ~= '' and name ~= '..' then names[#names + 1] = name end
	end
	if #names ~= #s.original - 1 then
		vis:info('Line count changed — use :fma to create, :fmd! to delete')
		return false
	end
	local ops = {}
	for i, name in ipairs(names) do
		local old = s.original[i + 1]
		if name ~= old then
			ops[#ops + 1] = {
				old = s.dir .. '/' .. old:gsub('/$', ''),
				new = (name:match('^/') and name or s.dir .. '/' .. name):gsub('/$', ''),
				old_name = old, new_name = name,
			}
		end
	end
	if #ops == 0 then return true end
	local ok, message = rename(s.dir, ops)
	vis:info(message)
	if ok then
		-- Returning from a browser should follow a file or ancestor we renamed.
		for _, browser in pairs(sessions) do
			local previous = browser.prev_file
			if previous then
				for _, op in ipairs(ops) do
					if previous == op.old or previous:sub(1, #op.old + 1) == op.old .. '/' then
						browser.prev_file = op.new .. previous:sub(#op.old + 1)
						break
					end
				end
			end
		end
		-- Renames have already happened, even if a subsequent write/refresh fails.
		s.original = {'..'}
		for _, name in ipairs(names) do s.original[#s.original + 1] = name end
		s.refresh_after_save = file
	end
	return ok
end)

vis.events.subscribe(vis.events.FILE_SAVE_POST, function(file)
	local s = sessions[file.path] or sessions[file.name]
	if not s or s.refresh_after_save ~= file then return end
	s.refresh_after_save = nil
	if session() == s and vis.win.file == file then refresh(s) end
end)

vis.events.subscribe(vis.events.QUIT, function()
	for path in pairs(sessions) do os.remove(path) end
end)

function M.get_status(win)
	local s = session(win)
	if not s then return end
	return string.format('%s  [%d]  sort:%s%s', s.dir, #s.original - 1,
		s.sort_mode, s.show_hidden and '' or '  (no hidden)')
end

vis.events.subscribe(vis.events.WIN_STATUS, function(win)
	local status = M.get_status(win)
	if status then win:status(status, ''); return true end
end)

return M
