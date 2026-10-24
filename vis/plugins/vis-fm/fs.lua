-- Filesystem operations shared by the file browser and bulk rename.

local function esc(s)
	return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function run(command)
	local ok = os.execute(command)
	return ok == true or ok == 0
end

local function output(command)
	local h = io.popen(command)
	if not h then return nil end
	local value = h:read("*l")
	local ok = h:close()
	if ok == true or ok == 0 then return value end
end

local function exists(path)
	return run("test -e " .. esc(path) .. " -o -L " .. esc(path))
end

-- GNU mv's no-clobber mode also protects against destinations appearing
-- after validation. It returns success when skipping, so check the source.
local function move(source, dest)
	return run("mv -nT -- " .. esc(source) .. " " .. esc(dest))
		and not exists(source)
end

local function trash(path)
	if run("command -v trash-put >/dev/null 2>&1") then
		return run("trash-put -- " .. esc(path))
	end
	local home = os.getenv("HOME")
	if not home then return false end
	local trash_files = home .. "/.local/share/Trash/files"
	local trash_info = home .. "/.local/share/Trash/info"
	if not run("mkdir -p -- " .. esc(trash_files) .. " " .. esc(trash_info)) then
		return false
	end
	local name = path:match("([^/]+)$")
	local info_path = output("mktemp -- " .. esc(trash_info .. "/" .. name .. ".XXXXXXXX.trashinfo"))
	if not info_path then return false end
	local dest = trash_files .. "/" .. info_path:match("([^/]+)%.trashinfo$")
	local info = io.open(info_path, "w")
	if not info then os.remove(info_path); return false end
	local encoded = path:gsub("([^%w/._~-])", function(c)
		return string.format("%%%02X", c:byte())
	end)
	local written = info:write(string.format("[Trash Info]\nPath=%s\nDeletionDate=%s\n",
		encoded, os.date("%Y-%m-%dT%H:%M:%S")))
	local closed = info:close()
	if not written or not closed or not move(path, dest) then
		os.remove(info_path)
		return false
	end
	return true
end

return {
	esc = esc, run = run, output = output, exists = exists, move = move, trash = trash,
}
