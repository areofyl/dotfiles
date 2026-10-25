local M = {
  text_colors = {
    dark = "#000000",
    light = "#ffffff"
  },
  -- Highlight six digit hex color codes
  six = true,
  -- Highlight three digit hex color hexcodes
  three = false,
}

M.extract_hex_colors = function(input_string)
	local pattern = "#([0-9a-fA-F]+)"
	local matches = {}

	local init = 1
	local match_end = 0
	while true do
		local match_start, hex
		match_start, match_end, hex = string.find(input_string, pattern, init + match_end)
		-- TODO: add better validation
		if match_start == nil or hex == nil then
			break
		end
		local following = input_string:sub(match_end + 1, match_end + 1)
		if not following:match('[%w_]') and
			((hex:len() == 3 and M.three) or (hex:len() == 6 and M.six)) then
			table.insert(matches, {
				starts = match_start,
				ends = match_end,
				hex = hex,
			})
		end
	end

	return matches
end

M.draw = function(win, colors)
	local offset = win.viewport['bytes'].start
	-- Keep lexer styles and the LSP diagnostic style (the maximum ID) intact.
	local lexer = win.syntax and vis.lexers.load(win.syntax, nil, true)
	local style_ids = {}
	for id = win.STYLE_LEXER_MAX - 1, 1, -1 do
		if not lexer or not lexer._TAGS[id] then style_ids[#style_ids + 1] = id end
	end
	local color_styles = {}
	for i, color in ipairs(colors) do
		local fg = M.text_colors.light

		if color.hex:len() == 3 then
			color.hex = string.gsub(color.hex,
				"([0-9a-fA-F])([0-9a-fA-F])([0-9a-fA-F])",
				"%1%1%2%2%3%3")
		end

		local r = tonumber(color.hex:sub(1, 2), 16)
		local g = tonumber(color.hex:sub(3, 4), 16)
		local b = tonumber(color.hex:sub(5, 6), 16)

		if (r * 30) + (g * 59) + (b * 11) > 12000 then
			fg = M.text_colors.dark
		end

		local style = "fore:" .. fg .. ",back:#" .. color.hex
		local id = color_styles[color.hex]
		if not id then
			id = table.remove(style_ids)
			if not id or not win:style_define(id, style) then break end
			color_styles[color.hex] = id
		end
		win:style(id, color.starts - 1 + offset, color.ends - 1 + offset)
		if color.ends >= win.viewport['bytes'].finish then
			break
		end
	end
end

M.on_higlight = function(win)
	local content = win.file:content(win.viewport['bytes'])
	local hex_colors = M.extract_hex_colors(content)
	M.draw(win, hex_colors)
end

vis.events.subscribe(vis.events.WIN_HIGHLIGHT, M.on_higlight)

return M
