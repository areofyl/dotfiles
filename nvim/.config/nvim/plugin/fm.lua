-- fm.lua — dired-style file manager
-- directory listing is a real buffer: edit to rename/move, :w to apply

local show_hidden = true
local sort_mode = "time" -- name, time, size
local preview_win, preview_buf, fm_win
local previewing = false
local preview_job = nil
local debounce_timer = nil
local au_group = vim.api.nvim_create_augroup("FM", { clear = true })
local cursor_memory = {} -- dir -> entry name to restore cursor on

local image_exts = {
  png = true, jpg = true, jpeg = true, gif = true,
  bmp = true, webp = true, svg = true, ico = true,
  tiff = true, tif = true,
}

local video_exts = {
  mp4 = true, mkv = true, webm = true, avi = true,
  mov = true, flv = true, wmv = true, m4v = true,
}

local external_exts = {
  png = true, jpg = true, jpeg = true, gif = true, bmp = true,
  webp = true, svg = true, ico = true, tiff = true, tif = true,
  pdf = true,
  mp4 = true, mkv = true, webm = true, avi = true, mov = true,
  flv = true, wmv = true, m4v = true,
  mp3 = true, flac = true, ogg = true, wav = true, m4a = true,
  doc = true, docx = true, xls = true, xlsx = true, ppt = true, pptx = true,
  odt = true, ods = true, odp = true,
}

local function ext_of(path)
  local e = path:match("%.(%w+)$")
  return e and e:lower()
end

-- highlights

local hl_ns = vim.api.nvim_create_namespace("fm_hl")

local media_exts = {
  png = true, jpg = true, jpeg = true, gif = true, bmp = true,
  webp = true, svg = true, ico = true, tiff = true, tif = true,
  mp4 = true, mkv = true, webm = true, avi = true, mov = true,
  flv = true, wmv = true, m4v = true,
  mp3 = true, flac = true, ogg = true, wav = true, m4a = true,
  pdf = true,
}

local archive_exts = {
  zip = true, tar = true, gz = true, bz2 = true, xz = true,
  zst = true, ["7z"] = true, rar = true, deb = true, rpm = true,
}

local function setup_hl()
  -- derive FmDir from Directory but add bold
  local dir_hl = vim.api.nvim_get_hl(0, { name = "Directory", link = false })
  dir_hl.bold = true
  vim.api.nvim_set_hl(0, "FmDir", dir_hl)
  vim.api.nvim_set_hl(0, "FmDirSlash", { link = "NonText" })
  vim.api.nvim_set_hl(0, "FmDotfile", { link = "Comment" })
  vim.api.nvim_set_hl(0, "FmExt", { fg = "#cf8164" })
  vim.api.nvim_set_hl(0, "FmExec", { bold = true, fg = "#57a65d" })
  vim.api.nvim_set_hl(0, "FmLink", { italic = true, fg = "#6fb5c4" })
  vim.api.nvim_set_hl(0, "FmMedia", { fg = "#c4a24d" })
  vim.api.nvim_set_hl(0, "FmArchive", { fg = "#cf8164" })
  vim.api.nvim_set_hl(0, "FmParent", { link = "NonText" })
end

setup_hl()

local function highlight_entries(buf, dir, entries)
  vim.api.nvim_buf_clear_namespace(buf, hl_ns, 0, -1)
  for i, entry in ipairs(entries) do
    local row = i - 1
    if entry == ".." then
      vim.api.nvim_buf_set_extmark(buf, hl_ns, row, 0, { end_col = 2, hl_group = "FmParent" })
    elseif entry:match("/$") then
      -- directory: name in bold, trailing / dimmed
      local name_len = #entry - 1
      vim.api.nvim_buf_set_extmark(buf, hl_ns, row, 0, { end_col = name_len, hl_group = "FmDir" })
      vim.api.nvim_buf_set_extmark(buf, hl_ns, row, name_len, { end_col = #entry, hl_group = "FmDirSlash" })
    else
      local path = dir .. "/" .. entry
      local lstat = vim.uv.fs_lstat(path)
      local is_link = lstat and lstat.type == "link"
      local is_exec = false
      if not is_link then
        local stat = vim.uv.fs_stat(path)
        if stat then
          local mode = stat.mode
          is_exec = bit.band(mode, 73) ~= 0 -- owner/group/other execute
        end
      end

      local ext = entry:match("%.(%w+)$")
      ext = ext and ext:lower()

      if is_link then
        vim.api.nvim_buf_set_extmark(buf, hl_ns, row, 0, { end_col = #entry, hl_group = "FmLink" })
      elseif entry:match("^%.") then
        vim.api.nvim_buf_set_extmark(buf, hl_ns, row, 0, { end_col = #entry, hl_group = "FmDotfile" })
      elseif ext and media_exts[ext] then
        vim.api.nvim_buf_set_extmark(buf, hl_ns, row, 0, { end_col = #entry, hl_group = "FmMedia" })
      elseif ext and archive_exts[ext] then
        vim.api.nvim_buf_set_extmark(buf, hl_ns, row, 0, { end_col = #entry, hl_group = "FmArchive" })
      elseif is_exec then
        vim.api.nvim_buf_set_extmark(buf, hl_ns, row, 0, { end_col = #entry, hl_group = "FmExec" })
      else
        -- regular file: dim the .extension part
        local dot_pos = entry:find("%.[^.]+$")
        if dot_pos then
          vim.api.nvim_buf_set_extmark(buf, hl_ns, row, dot_pos - 1, { end_col = #entry, hl_group = "FmExt" })
        end
      end
    end
  end
end

local function scan_dir(dir)
  local dirs, files = {}, {}
  local handle = vim.uv.fs_scandir(dir)
  if not handle then return {} end
  while true do
    local name, typ = vim.uv.fs_scandir_next(handle)
    if not name then break end
    if show_hidden or not name:match("^%.") then
      if typ == "directory" then
        table.insert(dirs, name .. "/")
      else
        table.insert(files, name)
      end
    end
  end

  local function sort_fn(a, b)
    if sort_mode == "name" then
      return a:lower() < b:lower()
    end
    local sa = vim.uv.fs_stat(dir .. "/" .. a:gsub("/$", ""))
    local sb = vim.uv.fs_stat(dir .. "/" .. b:gsub("/$", ""))
    if not sa or not sb then return a < b end
    if sort_mode == "time" then
      return sa.mtime.sec > sb.mtime.sec
    else -- size
      return sa.size > sb.size
    end
  end

  table.sort(dirs, sort_fn)
  table.sort(files, sort_fn)

  -- dirs first, then files
  local entries = {}
  for _, d in ipairs(dirs) do table.insert(entries, d) end
  for _, f in ipairs(files) do table.insert(entries, f) end
  return entries
end

local function file_info(path)
  local stat = vim.uv.fs_stat(path)
  if not stat then return nil end
  local size = stat.size
  local units = { "B", "K", "M", "G" }
  local i = 1
  while size >= 1024 and i < #units do
    size = size / 1024
    i = i + 1
  end
  local lstat = vim.uv.fs_lstat(path)
  local link = (lstat and lstat.type == "link") and " -> " .. (vim.uv.fs_readlink(path) or "?") or ""
  local size_str = i == 1 and ("%d%s"):format(size, units[i]) or ("%.1f%s"):format(size, units[i])
  local perms = ("%o"):format(stat.mode % 512)
  local mtime = os.date("%Y-%m-%d %H:%M", stat.mtime.sec)
  return perms .. "  " .. size_str .. "  " .. mtime .. link
end

local function list_dir_entries(path)
  local entries = {}
  local handle = vim.uv.fs_scandir(path)
  if not handle then return entries end
  while true do
    local name, typ = vim.uv.fs_scandir_next(handle)
    if not name then break end
    table.insert(entries, typ == "directory" and name .. "/" or name)
  end
  table.sort(entries)
  return entries
end

-- preview pane

local last_preview_path = nil

local function kill_preview_job()
  if preview_job then
    pcall(vim.fn.jobstop, preview_job)
    preview_job = nil
  end
end

local function clean_preview_buf()
  kill_preview_job()
  if preview_buf and vim.api.nvim_buf_is_valid(preview_buf) then
    pcall(vim.api.nvim_buf_delete, preview_buf, { force = true })
  end
  preview_buf = nil
  last_preview_path = nil
end

local function reset_preview_buf()
  if not preview_win or not vim.api.nvim_win_is_valid(preview_win) then return false end
  kill_preview_job()
  -- reuse existing buf if possible, only create new one for term previews
  if preview_buf and vim.api.nvim_buf_is_valid(preview_buf) then
    -- can't reuse a terminal buffer, need a fresh one
    if vim.bo[preview_buf].buftype == "terminal" then
      local old = preview_buf
      local ok, buf = pcall(vim.api.nvim_create_buf, false, true)
      if not ok then return false end
      preview_buf = buf
      pcall(vim.api.nvim_win_set_buf, preview_win, preview_buf)
      pcall(vim.api.nvim_buf_delete, old, { force = true })
    else
      vim.bo[preview_buf].modifiable = true
      pcall(vim.api.nvim_buf_set_lines, preview_buf, 0, -1, false, {})
    end
  else
    local ok, buf = pcall(vim.api.nvim_create_buf, false, true)
    if not ok then return false end
    preview_buf = buf
    pcall(vim.api.nvim_win_set_buf, preview_win, preview_buf)
  end
  return true
end

local function new_term_buf()
  if not preview_win or not vim.api.nvim_win_is_valid(preview_win) then return false end
  kill_preview_job()
  local old = preview_buf
  local ok, buf = pcall(vim.api.nvim_create_buf, false, true)
  if not ok then return false end
  preview_buf = buf
  pcall(vim.api.nvim_win_set_buf, preview_win, preview_buf)
  if old and old ~= preview_buf and vim.api.nvim_buf_is_valid(old) then
    pcall(vim.api.nvim_buf_delete, old, { force = true })
  end
  return true
end

local function preview_term(cmd)
  if not preview_win or not vim.api.nvim_win_is_valid(preview_win) then return end
  if not preview_buf or not vim.api.nvim_buf_is_valid(preview_buf) then return end
  vim.api.nvim_win_call(preview_win, function()
    local ok, job = pcall(vim.fn.termopen, cmd, {
      on_exit = function(id)
        if preview_job == id then preview_job = nil end
      end,
    })
    if ok then preview_job = job end
  end)
end

local function preview_size()
  if not preview_win or not vim.api.nvim_win_is_valid(preview_win) then return 40, 20 end
  return vim.api.nvim_win_get_width(preview_win), vim.api.nvim_win_get_height(preview_win)
end

local function get_entry_under_cursor()
  local ok, line = pcall(vim.api.nvim_get_current_line)
  if not ok or not line then return nil end
  line = vim.trim(line)
  if line == "" or line == ".." then return line end
  return line
end

local function get_fm_dir(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  return name:match("^fm://(.+)")
end

local function entry_path(dir, entry)
  if entry == ".." then
    return vim.fn.fnamemodify(dir:gsub("/$", ""), ":h"), "dir"
  end
  local is_dir = entry:match("/$") ~= nil
  local path = dir:gsub("/$", "") .. "/" .. entry:gsub("/$", "")
  return path, is_dir and "dir" or "file"
end

local function show_preview(dir, entry)
  if not preview_win or not vim.api.nvim_win_is_valid(preview_win) then return end
  if not entry or entry == "" then
    if not reset_preview_buf() then return end
    last_preview_path = nil
    return
  end

  local path, kind = entry_path(dir, entry)

  -- skip if already showing this path
  if path == last_preview_path then return end
  last_preview_path = path

  local name = vim.fn.fnamemodify(path, ":t")
  local ext = ext_of(path)
  local w, h = preview_size()

  pcall(function() vim.wo[preview_win].statusline = " " .. name .. " " end)

  if kind == "dir" then
    if not reset_preview_buf() then return end
    local ok, entries = pcall(list_dir_entries, path)
    if not ok then entries = {} end
    pcall(function()
      vim.wo[preview_win].statusline = (" %s/ (%d) "):format(name, #entries)
    end)
    vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false,
      #entries > 0 and entries or { "[empty]" })

  elseif image_exts[ext or ""] then
    if vim.fn.executable("chafa") == 0 then
      if not reset_preview_buf() then return end
      vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, { "need chafa for image preview" })
      return
    end
    if not new_term_buf() then return end
    preview_term({ "chafa", "--format=symbols", "--work=1", "--animate=off", "--polite=on", "--size=" .. w .. "x" .. h, path })

  elseif ext == "pdf" then
    if vim.fn.executable("pdftoppm") == 0 or vim.fn.executable("chafa") == 0 then
      if not reset_preview_buf() then return end
      vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, { "need poppler + chafa for pdf preview" })
      return
    end
    if not new_term_buf() then return end
    local tmp = os.tmpname() .. ".png"
    preview_term({ "sh", "-c", ("pdftoppm -f 1 -l 1 -r 72 -png %s > %s && chafa --format=symbols --work=1 --animate=off --polite=on --size=%dx%d %s; rm -f %s"):format(
      vim.fn.shellescape(path), vim.fn.shellescape(tmp), w, h, vim.fn.shellescape(tmp), vim.fn.shellescape(tmp)) })

  elseif video_exts[ext or ""] then
    if vim.fn.executable("ffmpeg") == 0 or vim.fn.executable("chafa") == 0 then
      if not reset_preview_buf() then return end
      vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, { "need ffmpeg + chafa for video preview" })
      return
    end
    if not new_term_buf() then return end
    local tmp = os.tmpname() .. ".png"
    preview_term({ "sh", "-c", ("ffmpeg -v quiet -y -i %s -vf scale=320:-1 -frames:v 1 %s && chafa --format=symbols --work=1 --animate=off --polite=on --size=%dx%d %s; rm -f %s"):format(
      vim.fn.shellescape(path), vim.fn.shellescape(tmp), w, h, vim.fn.shellescape(tmp), vim.fn.shellescape(tmp)) })

  else
    if not reset_preview_buf() then return end
    local ok, lines = pcall(vim.fn.readfile, path, "", 200)
    if not ok or not lines then
      vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, { "[cannot read]" })
      return
    end
    for _, l in ipairs(lines) do
      if l:match("[%z\1-\8\14-\31]") then
        vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, { "[binary]" })
        return
      end
    end
    local info = file_info(path)
    if info then table.insert(lines, 1, info); table.insert(lines, 2, "") end
    vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, lines)
    local ft_ok, ft = pcall(vim.filetype.match, { filename = path, buf = preview_buf })
    if ft_ok and ft then vim.bo[preview_buf].filetype = ft end
  end
end

local function close_preview()
  previewing = false
  if debounce_timer then
    pcall(function() debounce_timer:stop(); debounce_timer:close() end)
    debounce_timer = nil
  end
  kill_preview_job()
  if preview_win and vim.api.nvim_win_is_valid(preview_win) then
    pcall(vim.api.nvim_win_close, preview_win, true)
  end
  clean_preview_buf()
  preview_win = nil
  last_preview_path = nil
end

local function start_preview(buf)
  if previewing then return end
  previewing = true
  fm_win = vim.api.nvim_get_current_win()

  vim.cmd("botright vnew")
  preview_win = vim.api.nvim_get_current_win()
  preview_buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_win_set_width(preview_win, math.floor(vim.o.columns / 3))
  vim.wo[preview_win].number = false
  vim.wo[preview_win].relativenumber = false
  vim.wo[preview_win].signcolumn = "no"
  vim.wo[preview_win].foldcolumn = "0"
  vim.wo[preview_win].winfixwidth = true
  vim.wo[preview_win].statusline = " preview "

  vim.api.nvim_set_current_win(fm_win)

  local dir = get_fm_dir(buf)
  if dir then
    local entry = get_entry_under_cursor(buf)
    if entry and entry ~= "" then
      vim.schedule(function() pcall(show_preview, dir, entry) end)
    end
  end
end

local function schedule_preview(buf)
  if not debounce_timer then
    debounce_timer = vim.uv.new_timer()
  end
  debounce_timer:stop()
  debounce_timer:start(50, 0, vim.schedule_wrap(function()
    if not previewing then return end
    if not fm_win or not vim.api.nvim_win_is_valid(fm_win) then return end
    if vim.api.nvim_get_current_win() ~= fm_win then return end
    local dir = get_fm_dir(buf)
    if not dir then return end
    local entry = get_entry_under_cursor(buf)
    if entry then pcall(show_preview, dir, entry) end
  end))
end

-- trash

local function trash_path(path)
  if vim.fn.executable("trash-put") == 1 then
    vim.fn.system({ "trash-put", path })
  else
    local name = vim.fn.fnamemodify(path, ":t")
    local trash_files = vim.fn.expand("~/.local/share/Trash/files")
    local trash_info = vim.fn.expand("~/.local/share/Trash/info")
    vim.fn.mkdir(trash_files, "p")
    vim.fn.mkdir(trash_info, "p")
    local dest_name = name
    local n = 1
    while vim.uv.fs_stat(trash_files .. "/" .. dest_name) do
      dest_name = name .. "." .. n
      n = n + 1
    end
    vim.uv.fs_rename(path, trash_files .. "/" .. dest_name)
    vim.fn.writefile(vim.split(
      ("[Trash Info]\nPath=%s\nDeletionDate=%s\n"):format(path, os.date("%Y-%m-%dT%H:%M:%S")),
      "\n"), trash_info .. "/" .. dest_name .. ".trashinfo")
  end
end

-- core: open directory

local fm_refresh

local function fm_open(dir)
  dir = vim.fn.fnamemodify(dir, ":p"):gsub("/$", "")
  if vim.fn.isdirectory(dir) == 0 then return end

  local entries = scan_dir(dir)

  -- prepend ..
  table.insert(entries, 1, "..")

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, entries)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_name(buf, "fm://" .. dir)
  vim.bo[buf].buftype = "acwrite"
  vim.bo[buf].modified = false
  vim.bo[buf].filetype = "fm"
  vim.b[buf].fm_original = vim.deepcopy(entries)
  highlight_entries(buf, dir, entries)

  local count = #entries - 1 -- exclude ..
  vim.wo.statusline = (" %s  [%d]  sort:%s "):format(dir, count, sort_mode)
  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.wo.cursorline = true
  vim.wo.signcolumn = "no"

  -- start preview
  if not previewing then
    start_preview(buf)
  end

  -- save = apply renames/moves
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = function()
      local new = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local original = vim.b[buf].fm_original or {}
      -- skip .. line
      local new_entries = {}
      local orig_entries = {}
      for i = 1, #original do
        if original[i] ~= ".." then
          table.insert(orig_entries, original[i])
        end
      end
      for i = 1, #new do
        local line = vim.trim(new[i])
        if line ~= ".." and line ~= "" then
          table.insert(new_entries, line)
        end
      end

      if #new_entries ~= #orig_entries then
        vim.notify("Line count changed — use gd to delete, ga to create", vim.log.levels.ERROR)
        return
      end

      local ops = {}
      for i, old_name in ipairs(orig_entries) do
        local new_name = new_entries[i]
        if new_name ~= old_name then
          local old_path = dir .. "/" .. old_name:gsub("/$", "")
          -- resolve relative paths (../ etc)
          local new_path
          if new_name:match("^/") then
            new_path = new_name:gsub("/$", "")
          else
            new_path = vim.fn.fnamemodify(dir .. "/" .. new_name:gsub("/$", ""), ":p"):gsub("/$", "")
          end
          table.insert(ops, { old = old_path, new = new_path, display_old = old_name, display_new = new_name })
        end
      end

      if #ops == 0 then
        vim.notify("No changes")
        vim.bo[buf].modified = false
        return
      end

      local preview_lines = { "Rename operations:" }
      for _, op in ipairs(ops) do
        table.insert(preview_lines, "  " .. op.display_old .. " -> " .. op.display_new)
      end
      table.insert(preview_lines, "Apply? [y/N]")
      vim.api.nvim_echo({{ table.concat(preview_lines, "\n") }}, false, {})

      local ok = vim.fn.nr2char(vim.fn.getchar())
      if ok ~= "y" and ok ~= "Y" then
        vim.notify("Cancelled")
        return
      end

      for _, op in ipairs(ops) do
        local parent = vim.fn.fnamemodify(op.new, ":h")
        if vim.fn.isdirectory(parent) == 0 then
          vim.fn.mkdir(parent, "p")
        end
        local ret = vim.uv.fs_rename(op.old, op.new)
        if not ret then
          vim.notify("Failed: " .. op.old .. " -> " .. op.new, vim.log.levels.ERROR)
        end
      end

      vim.notify(#ops .. " file(s) renamed")
      -- refresh
      fm_refresh(buf, dir)
    end,
  })

  -- keymaps

  local function map(mode, lhs, rhs, opts)
    opts = opts or {}
    opts.buffer = buf
    vim.keymap.set(mode, lhs, rhs, opts)
  end

  -- enter: descend into dir or open file
  map("n", "<CR>", function()
    local entry = get_entry_under_cursor()
    if not entry or entry == "" then return end
    local path, kind = entry_path(dir, entry)
    if kind == "dir" then
      cursor_memory[dir] = entry
      close_preview()
      vim.api.nvim_buf_delete(buf, { force = true })
      fm_open(path)
    else
      local ext = ext_of(path)
      if ext and external_exts[ext] then
        vim.fn.jobstart({ "xdg-open", path }, { detach = true })
      else
        close_preview()
        vim.api.nvim_buf_delete(buf, { force = true })
        vim.cmd("edit " .. vim.fn.fnameescape(path))
      end
    end
  end)

  -- - go up
  map("n", "-", function()
    local parent = vim.fn.fnamemodify(dir, ":h")
    cursor_memory[parent] = vim.fn.fnamemodify(dir, ":t") .. "/"
    close_preview()
    vim.api.nvim_buf_delete(buf, { force = true })
    fm_open(parent)
  end)

  -- q quit
  map("n", "q", function()
    close_preview()
    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  -- gd trash
  map("n", "gd", function()
    local entry = get_entry_under_cursor()
    if not entry or entry == ".." then return end
    local path = entry_path(dir, entry)
    if vim.fn.confirm("Trash " .. entry .. "?", "&Yes\n&No") ~= 1 then return end
    trash_path(path)
    fm_refresh(buf, dir)
  end)

  -- gc chmod
  map("n", "gc", function()
    local entry = get_entry_under_cursor()
    if not entry or entry == ".." then return end
    local path = entry_path(dir, entry)
    local stat = vim.uv.fs_stat(path)
    if not stat then return end
    local current = ("%o"):format(stat.mode % 512)
    vim.ui.input({ prompt = "chmod: ", default = current }, function(mode)
      if not mode or mode == "" or mode == current then return end
      vim.fn.system({ "chmod", mode, path })
      fm_refresh(buf, dir)
    end)
  end)

  -- ga create file/dir (end with / for dir)
  map("n", "ga", function()
    vim.ui.input({ prompt = "New (/ = dir): " }, function(name)
      if not name or name == "" then return end
      local full = dir .. "/" .. name
      if name:match("/$") then
        vim.fn.mkdir(full:gsub("/$", ""), "p")
      else
        vim.fn.mkdir(vim.fn.fnamemodify(full, ":h"), "p")
        vim.fn.writefile({}, full)
      end
      fm_refresh(buf, dir)
    end)
  end)

  -- gy yank file to clipboard
  map("n", "gy", function()
    local entry = get_entry_under_cursor()
    if not entry or entry == ".." then return end
    local path, kind = entry_path(dir, entry)
    if kind ~= "file" then return end
    local mime = vim.fn.system({ "file", "-b", "--mime-type", path }):gsub("%s+$", "")
    if vim.v.shell_error ~= 0 or mime == "" then return end
    vim.fn.system({ "sh", "-c", "wl-copy --type " .. vim.fn.shellescape(mime) .. " < " .. vim.fn.shellescape(path) })
    vim.notify("Copied " .. entry)
  end)

  -- gs cycle sort
  map("n", "gs", function()
    if sort_mode == "name" then sort_mode = "time"
    elseif sort_mode == "time" then sort_mode = "size"
    else sort_mode = "name" end
    fm_refresh(buf, dir)
  end)

  -- gh toggle hidden
  map("n", "gh", function()
    show_hidden = not show_hidden
    fm_refresh(buf, dir)
  end)

  -- gp toggle preview
  map("n", "gp", function()
    if previewing then
      close_preview()
    else
      start_preview(buf)
    end
  end)

  -- gx flatten subdir
  map("n", "gx", function()
    local entry = get_entry_under_cursor()
    if not entry or not entry:match("/$") then
      vim.notify("Not a directory", vim.log.levels.WARN)
      return
    end
    local subdir_name = entry:gsub("/$", "")
    if vim.fn.confirm("Flatten " .. subdir_name .. "/?", "&Yes\n&No") ~= 1 then return end
    local subdir_path = dir .. "/" .. subdir_name
    local contents = scan_dir(subdir_path)
    if #contents == 0 then
      vim.fn.delete(subdir_path, "d")
      vim.notify("Removed empty directory: " .. subdir_name)
    else
      local moved = 0
      for _, e in ipairs(contents) do
        local old = subdir_path .. "/" .. e:gsub("/$", "")
        local new = dir .. "/" .. e:gsub("/$", "")
        if vim.uv.fs_stat(new) then
          vim.notify("Skipped (already exists): " .. e, vim.log.levels.WARN)
        else
          if vim.uv.fs_rename(old, new) then
            moved = moved + 1
          else
            vim.notify("Failed to move: " .. e, vim.log.levels.ERROR)
          end
        end
      end
      vim.fn.delete(subdir_path, "rf")
      vim.notify(moved .. " file(s) released from " .. subdir_name)
    end
    fm_refresh(buf, dir)
  end)

  -- ? help
  map("n", "?", function()
    local help = {
      "fm keybinds:",
      "",
      "  <CR>    open file / enter dir",
      "  -       go up",
      "  q       quit",
      "  /       path navigation",
      "",
      "  ga      create file/dir (/ suffix = dir)",
      "  gd      trash",
      "  gc      chmod",
      "  gs      cycle sort (name/time/size)",
      "  gh      toggle hidden files",
      "  gp      toggle preview",
      "  gx      flatten subdir",
      "  gy      yank file to clipboard",
      "",
      "  :w      apply renames (edit names in buffer)",
      "  ?       this help",
    }
    vim.api.nvim_echo({{ table.concat(help, "\n"), "Normal" }}, false, {})
    vim.fn.getchar()
    vim.cmd("echo ''")
  end)

  -- / path navigation with tab completion
  map("n", "/", function()
    local input = ""
    local cur_dir = dir
    local cur_buf = buf
    local matches_display = nil

    local function full_prompt()
      local rel = cur_dir:sub(#dir + 1)
      if rel ~= "" then rel = rel:sub(2) .. "/" end
      return "/" .. rel .. input
    end

    local function redraw()
      local prompt = full_prompt()
      if matches_display then
        local avail = vim.o.columns - 1
        local mstr = matches_display
        if #mstr > avail then mstr = mstr:sub(1, avail - 1) .. "…" end
        vim.wo.statusline = " " .. mstr
        matches_display = nil
      end
      vim.cmd("redraw!")
      vim.cmd("echohl Question")
      vim.cmd("echon " .. vim.fn.string(prompt))
      vim.cmd("echohl None")
    end

    local function navigate_to(target)
      target = target:gsub("/$", "")
      if vim.fn.isdirectory(target) == 0 then return false end
      cursor_memory[cur_dir] = get_entry_under_cursor()
      close_preview()
      vim.api.nvim_buf_delete(cur_buf, { force = true })
      fm_open(target)
      cur_buf = vim.api.nvim_get_current_buf()
      cur_dir = target
      input = ""
      return true
    end

    redraw()

    while true do
      local ok, c = pcall(vim.fn.getcharstr)
      if not ok then vim.cmd("echo ''"); return end

      if c == "\27" then
        vim.cmd("echo ''")
        return

      elseif c == "\r" then
        vim.cmd("echo ''")
        if input == "" then return end
        local target = cur_dir .. "/" .. input
        target = vim.fn.fnamemodify(target, ":p"):gsub("/$", "")
        if vim.fn.isdirectory(target) == 1 then
          navigate_to(target)
        elseif vim.fn.filereadable(target) == 1 then
          close_preview()
          vim.api.nvim_buf_delete(cur_buf, { force = true })
          vim.cmd("edit " .. vim.fn.fnameescape(target))
        end
        return

      elseif c == "\t" then
        local matches = {}
        local handle = vim.uv.fs_scandir(cur_dir)
        if handle then
          while true do
            local name, typ = vim.uv.fs_scandir_next(handle)
            if not name then break end
            if not show_hidden and name:match("^%.") then goto skip end
            if input == "" or name:sub(1, #input):lower() == input:lower() then
              table.insert(matches, typ == "directory" and name .. "/" or name)
            end
            ::skip::
          end
        end
        table.sort(matches)

        if #matches == 1 then
          local match = matches[1]
          if match:match("/$") then
            navigate_to(cur_dir .. "/" .. match:gsub("/$", ""))
          else
            input = match
          end
        elseif #matches > 1 then
          local common = matches[1]
          for i = 2, #matches do
            local m = matches[i]
            local j = 0
            while j < #common and j < #m and common:sub(j+1, j+1):lower() == m:sub(j+1, j+1):lower() do
              j = j + 1
            end
            common = common:sub(1, j)
          end
          input = common
          matches_display = table.concat(matches, " ")
        end
        redraw()

      elseif c == "\8" or c == "\127" or c == vim.keycode("<BS>") then
        if input == "" then
          local parent = vim.fn.fnamemodify(cur_dir, ":h")
          if parent ~= cur_dir then
            navigate_to(parent)
          end
        else
          input = input:sub(1, -2)
        end
        redraw()

      elseif c == vim.keycode("<Left>") then
        if #input > 0 then
          input = input:sub(1, -2)
          redraw()
        end

      elseif c == vim.keycode("<Right>") then
        -- tab-complete single match on right arrow
        local matches = {}
        local handle = vim.uv.fs_scandir(cur_dir)
        if handle then
          while true do
            local name, typ = vim.uv.fs_scandir_next(handle)
            if not name then break end
            if not show_hidden and name:match("^%.") then goto skip_r end
            if input ~= "" and name:sub(1, #input):lower() == input:lower() then
              table.insert(matches, typ == "directory" and name .. "/" or name)
            end
            ::skip_r::
          end
        end
        if #matches == 1 and matches[1]:match("/$") then
          navigate_to(cur_dir .. "/" .. matches[1]:gsub("/$", ""))
        end
        redraw()

      elseif c == vim.keycode("<Up>") then
        local parent = vim.fn.fnamemodify(cur_dir, ":h")
        if parent ~= cur_dir then
          navigate_to(parent)
        end
        redraw()

      elseif c == vim.keycode("<Down>") then
        -- enter first matching dir
        local matches = {}
        local handle = vim.uv.fs_scandir(cur_dir)
        if handle then
          while true do
            local name, typ = vim.uv.fs_scandir_next(handle)
            if not name then break end
            if not show_hidden and name:match("^%.") then goto skip_d end
            if typ == "directory" and (input == "" or name:sub(1, #input):lower() == input:lower()) then
              table.insert(matches, name)
            end
            ::skip_d::
          end
        end
        table.sort(matches)
        if #matches > 0 then
          navigate_to(cur_dir .. "/" .. matches[1])
        end
        redraw()

      elseif c:match("^[%g ]$") then
        input = input .. c
        redraw()
      end
    end
  end)

  -- cursor move updates preview
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = au_group,
    buffer = buf,
    callback = function()
      if previewing then schedule_preview(buf) end
    end,
  })

  -- close preview when fm buffer is gone
  vim.api.nvim_create_autocmd("BufDelete", {
    group = au_group,
    buffer = buf,
    callback = function()
      close_preview()
    end,
  })

  -- restore cursor to remembered entry, or first real entry
  local target = cursor_memory[dir]
  local target_line = 2
  if target then
    for i, e in ipairs(entries) do
      if e == target then
        target_line = i
        break
      end
    end
  end
  pcall(vim.api.nvim_win_set_cursor, 0, { target_line, 0 })
end

fm_refresh = function(buf, dir)
  local entries = scan_dir(dir)
  table.insert(entries, 1, "..")
  vim.bo[buf].buftype = ""
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, entries)
  vim.bo[buf].buftype = "acwrite"
  vim.bo[buf].modified = false
  vim.b[buf].fm_original = vim.deepcopy(entries)
  highlight_entries(buf, dir, entries)
  local count = #entries - 1
  vim.wo.statusline = (" %s  [%d]  sort:%s "):format(dir, count, sort_mode)
end

-- commands

vim.api.nvim_create_user_command("Fm", function(opts)
  local dir = opts.args ~= "" and opts.args or vim.fn.expand("%:p:h")
  if dir == "" then dir = vim.fn.getcwd() end
  fm_open(dir)
end, { nargs = "?", complete = "dir" })

-- leader-e opens fm instead of netrw
vim.keymap.set("n", "<leader>e", function()
  local dir = vim.fn.expand("%:p:h")
  if dir == "" or vim.fn.isdirectory(dir) == 0 then
    dir = vim.fn.getcwd()
  end
  fm_open(dir)
end)

-- re-apply highlight groups on colorscheme change
vim.api.nvim_create_autocmd("ColorScheme", {
  group = au_group,
  callback = setup_hl,
})

-- hijack directory opens (replaces netrw)
vim.api.nvim_create_autocmd("BufEnter", {
  group = au_group,
  callback = function(args)
    local path = vim.api.nvim_buf_get_name(args.buf)
    if path ~= "" and vim.fn.isdirectory(path) == 1 then
      vim.api.nvim_buf_delete(args.buf, { force = true })
      fm_open(path)
    end
  end,
})
