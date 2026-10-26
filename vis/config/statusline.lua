return function(win)
	local file = win.file
	local left = (file.name or '[No Name]') .. (file.modified and ' [+]' or '')
	local right = string.format('%d:%d / %d',
		win.selection.line, win.selection.col, #file.lines)
	win:status(left, right)
end
