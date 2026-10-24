-- vis-fm: dired-style file manager for vis
-- navigate dirs, open files, rename by editing buffer + :w

local fs = require('plugins/vis-fm/fs')
local rename = require('plugins/vis-fm/rename')
local esc, run, output = fs.esc, fs.run, fs.output
local exists, trash = fs.exists, fs.trash

local M = {}

local FM_FILE = os.tmpname()
local fm_dir = nil
local fm_original = {}
local show_hidden = true
local sort_mode = "time"
local cursor_memory = {}
local prev_file = nil

vis.events.subscribe(vis.events.QUIT, function()
	os.remove(FM_FILE)
end)

local function up()
	local parent = fm_dir:match("(.+)/[^/]+$") or "/"
	local name = fm_dir:match("([^/]+)$")
	if name then cursor_memory[parent] = name .. "/" end
	M.open(parent)
end

local function vis_path(p)
	return p:gsub("\\", "\\\\"):gsub(" ", "\\ ")
end

function M.active(win)
	win = win or vis.win
	return fm_dir ~= nil and win and win.file
		and win.file.name == FM_FILE
end

local function get_line()
	if not vis.win then return nil end
	local l = vis.win.file.lines[vis.win.selection.line]
	if l then return l:match("^(.-)%s*$") end
	return nil
end

local function scan(d)
	local flags = show_hidden and "-1Ap" or "-1p"
	local sf = ""
	if sort_mode == "time" then sf = " --sort=time"
	elseif sort_mode == "size" then sf = " --sort=size" end

	local h = io.popen("ls " .. flags .. sf .. " " .. esc(d) .. " 2>/dev/null")
	if not h then return {} end
	local t = {}
	for l in h:lines() do
		if l ~= "" then t[#t + 1] = l end
	end
	h:close()
	return t
end

local function write_listing(entries)
	local f = io.open(FM_FILE, "w")
	if not f then return false end
	for _, e in ipairs(entries) do f:write(e .. "\n") end
	f:close()
	return true
end

local function refresh()
	if not fm_dir then return end
	local entries = scan(fm_dir)
	table.insert(entries, 1, "..")
	fm_original = entries

	if not write_listing(entries) then return end
	if not M.active() then
		vis:command("e " .. FM_FILE)
	else
		vis:command("e!")
	end

	local target = cursor_memory[fm_dir]
	if target then
		for i, e in ipairs(entries) do
			if e == target then
				vis.win.selection:to(i, 1)
				return
			end
		end
	end
	if #entries > 1 then
		vis.win.selection:to(2, 1)
	end
end

function M.open(d)
	d = output("realpath -- " .. esc(d) .. " 2>/dev/null") or d

	if not M.active() and vis.win and vis.win.file and vis.win.file.name then
		prev_file = vis.win.file.name
	end

	fm_dir = d
	refresh()
end

local function enter()
	local l = get_line()
	if not l or l == "" then return end

	if l == ".." then
		up()
		return
	end

	cursor_memory[fm_dir] = l
	local path = fm_dir .. "/" .. l:gsub("/$", "")
	if l:match("/$") then
		M.open(path)
	else
		os.execute("xdg-open " .. esc(path) .. " >/dev/null 2>&1 &")
	end
end

-- Browser bindings only consume keys while its buffer is active.
local function map(key, action)
	vis:map(vis.modes.NORMAL, key, function()
		if not M.active() then return end
		action()
		return true
	end)
end

map("<Enter>", enter)
map("-", up)

map("q", function()
	fm_dir = nil
	fm_original = {}
	if prev_file then
		vis:command("e " .. vis_path(prev_file))
		prev_file = nil
	else
		vis:command("q!")
	end
end)

map("gh", function()
	show_hidden = not show_hidden
	refresh()
end)

map("gs", function()
	if sort_mode == "name" then sort_mode = "time"
	elseif sort_mode == "time" then sort_mode = "size"
	else sort_mode = "name" end
	refresh()
end)

map("ga", function()
	vis:feedkeys(":fma ")
end)

map("gd", function()
	local l = get_line()
	if not l or l == ".." or l == "" then return end
	vis:info("Delete " .. l .. "? Run :fmd! to confirm")
end)

map("g?", function()
	vis:info("fm: <CR>=open  -=up  q=quit  gh=hidden  gs=sort  ga=new  gd=del  :w=rename  g?=help")
end)

-- leader-e
vis:map(vis.modes.NORMAL, " e", function()
	local d = "."
	if vis.win and vis.win.file and vis.win.file.name then
		local dir = vis.win.file.name:match("(.+)/[^/]+$")
		if dir then d = dir end
	end
	M.open(d)
end, "Open file browser")

-- commands

vis:command_register("fma", function(argv)
	if not M.active() then return true end
	if #argv == 0 then
		vis:info("Usage: :fma <name> (end with / for directory)")
		return true
	end
	local name = table.concat(argv, " ")
	local path = fm_dir .. "/" .. name
	local target = path:gsub("/+$", "")
	if exists(target) then
		vis:info("Already exists: " .. name)
		return true
	end
	local ok
	if name:match("/$") then
		ok = run("mkdir -p -- " .. esc(target))
	else
		local parent = path:match("(.+)/[^/]+$")
		-- noclobber makes creation exclusive, including a concurrent creator.
		ok = run("mkdir -p -- " .. esc(parent) .. " && (set -C; : > " .. esc(path) .. ")")
	end
	if not ok then vis:info("Failed to create: " .. name) end
	refresh()
	return true
end, "Create file or directory (/ suffix for dir)")

vis:command_register("fmd", function(argv, force)
	if not M.active() then return true end
	local l = get_line()
	if not l or l == ".." or l == "" then return true end
	local path = fm_dir .. "/" .. l:gsub("/$", "")
	if not force then
		vis:info("Delete " .. l .. "? Use :fmd! to confirm")
		return true
	end
	if trash(path) then
		vis:info("Trashed " .. l)
	else
		vis:info("Failed to trash: " .. l)
	end
	refresh()
	return true
end, "Delete entry under cursor (use ! to confirm)")

-- rename on :w — intercept save on fm buffer

vis.events.subscribe(vis.events.FILE_SAVE_PRE, function(file, path)
	if path ~= FM_FILE or not fm_dir then return true end

	local new = {}
	for i = 1, #file.lines do
		local line = file.lines[i]
		if line then
			line = line:match("^(.-)%s*$")
			if line ~= "" and line ~= ".." then
				new[#new + 1] = line
			end
		end
	end

	local orig = {}
	for _, e in ipairs(fm_original) do
		if e ~= ".." then orig[#orig + 1] = e end
	end

	if #new ~= #orig then
		vis:info("Line count changed — use :fma to create, :fmd! to delete")
		return false
	end

	local ops = {}
	for i, old_name in ipairs(orig) do
		local new_name = new[i]
		if new_name and new_name ~= old_name then
			local old_path = fm_dir .. "/" .. old_name:gsub("/$", "")
			local new_path
			if new_name:match("^/") then
				new_path = new_name:gsub("/$", "")
			else
				new_path = fm_dir .. "/" .. new_name:gsub("/$", "")
			end
			ops[#ops + 1] = { old = old_path, new = new_path,
				old_name = old_name, new_name = new_name }
		end
	end

	if #ops == 0 then
		vis:info("No changes")
		return false
	end

	local _, message, attempted = rename(fm_dir, ops)
	vis:info(message)
	if attempted then refresh() end
	return false
end)

-- status bar

function M.get_status(win)
	if not M.active(win) then return nil end
	local count = #fm_original - 1
	return string.format("%s  [%d]  sort:%s%s",
		fm_dir, count < 0 and 0 or count, sort_mode,
		show_hidden and "" or "  (no hidden)")
end

return M
