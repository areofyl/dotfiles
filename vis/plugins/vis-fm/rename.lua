-- Validate a batch, stage its sources, then commit or roll back.
local fs = require('plugins/vis-fm/fs')
local esc, run, output = fs.esc, fs.run, fs.output
local exists, move = fs.exists, fs.move

return function(fm_dir, ops)
	local sources, destinations = {}, {}
	for _, op in ipairs(ops) do
		op.old = output("realpath -ms -- " .. esc(op.old))
		op.new = output("realpath -ms -- " .. esc(op.new))
		if not op.old or not op.new or not exists(op.old) then
			return false, "Invalid rename path or missing source"
		end
		if destinations[op.new] then
			return false, "Duplicate destination: " .. op.new_name
		end
		sources[op.old], destinations[op.new] = true, true
	end
	for _, op in ipairs(ops) do
		if exists(op.new) and not sources[op.new] then
			return false, "Already exists: " .. op.new_name
		end
		-- Moving an ancestor would also move other sources or destinations.
		-- Reject these batches before touching any files.
		for _, other in ipairs(ops) do
			for _, path in ipairs({other.old, other.new}) do
				if path:sub(1, #op.old + 1) == op.old .. "/"
					or path:sub(1, #op.new + 1) == op.new .. "/" then
					return false, "Overlapping rename paths: " .. op.new_name
				end
			end
		end
	end

	local staging = output("mktemp -d -- " .. esc(fm_dir .. "/.vis-fm-XXXXXXXX"))
	if not staging then
		return false, "Cannot create rename staging directory"
	end
	local failed, message
	for i, op in ipairs(ops) do
		op.temp = staging .. "/" .. i
		if not move(op.old, op.temp) then failed = op; break end
		op.staged = true
	end
	if not failed then
		for _, op in ipairs(ops) do
			local parent = op.new:match("(.+)/[^/]+$")
			if not run("mkdir -p -- " .. esc(parent)) or not move(op.temp, op.new) then
				failed = op
				break
			end
			op.committed = true
		end
	end
	if failed then
		local restored = true
		for _, op in ipairs(ops) do
			if op.committed and not move(op.new, op.temp) then restored = false end
		end
		for _, op in ipairs(ops) do
			if op.staged and exists(op.temp) and not move(op.temp, op.old) then
				restored = false
			end
		end
		message = "Rename failed: " .. failed.old_name .. " -> " .. failed.new_name
			.. (restored and " (original names restored)" or " (recovery files: " .. staging .. ")")
	else
		message = #ops .. " file(s) renamed"
	end
	run("rmdir -- " .. esc(staging))

	return not failed, message, true
end
