-- netrw config + file browser enhancements
-- preview pane, bookmarks, trash, rename, clipboard yank, chmod

vim.g.netrw_banner = 0
vim.g.netrw_liststyle = 0
vim.g.netrw_keepdir = 0

vim.keymap.set("n", "<leader>e", function()
  local dir = vim.fn.expand("%:p:h")
  if dir == "" or vim.fn.isdirectory(dir) == 0 then
    dir = vim.fn.getcwd()
  end
  vim.cmd("Explore " .. vim.fn.fnameescape(dir))
end)

local preview_win, preview_buf, netrw_win
local au_group = vim.api.nvim_create_augroup("NetrwPreview", { clear = true })
local previewing = false
local dir_history = {}
local preview_job = nil
local debounce_timer = nil
local show_hidden = false
local sort_mode = "name" -- name, time, size

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

local function get_netrw_entry()
  local dir = vim.b.netrw_curdir
  if not dir then return nil, nil end

  local ok, line = pcall(vim.api.nvim_get_current_line)
  if not ok or not line then return nil, nil end
  line = vim.trim(line)
  if line == "" or line == "./" then return nil, nil end

  line = line:gsub("^[│├└─┬ ]+", "") -- strip tree markers
  line = line:gsub("^@", "") -- strip symlink marker
  local is_dir = line:match("/$") ~= nil
  line = line:gsub("/$", "")
  line = line:gsub("%*$", "") -- strip executable marker
  if line == "" then return nil, nil end

  local path
  if line == ".." then
    path = vim.fn.fnamemodify(dir:gsub("/$", ""), ":h")
  else
    path = dir:gsub("/$", "") .. "/" .. line
  end

  if is_dir or line == ".." then
    return vim.fn.isdirectory(path) == 1 and path or nil, "dir"
  end
  return vim.fn.filereadable(path) == 1 and path or nil, "file"
end

local function get_visual_entries()
  local start = vim.fn.line("'<")
  local finish = vim.fn.line("'>")
  local dir = vim.b.netrw_curdir
  if not dir then return {} end

  local entries = {}
  for lnum = start, finish do
    local line = vim.trim(vim.fn.getline(lnum))
    if line ~= "" and line ~= "./" and line ~= ".." then
      line = line:gsub("^[│├└─┬ ]+", "")
      line = line:gsub("^@", "")
      line = line:gsub("/$", "")
      line = line:gsub("%*$", "")
      if line ~= "" then
        local path = dir:gsub("/$", "") .. "/" .. line
        if vim.uv.fs_stat(path) then
          table.insert(entries, path)
        end
      end
    end
  end
  return entries
end

local function list_dir(path)
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

local function kill_preview_job()
  if preview_job then
    pcall(vim.fn.jobstop, preview_job)
    preview_job = nil
  end
end

local function swap_preview_buf(old)
  if not preview_win or not vim.api.nvim_win_is_valid(preview_win) then return false end
  kill_preview_job()
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

local function clean_preview_buf()
  kill_preview_job()
  if preview_buf and vim.api.nvim_buf_is_valid(preview_buf) then
    pcall(vim.api.nvim_buf_delete, preview_buf, { force = true })
  end
  preview_buf = nil
end

local function close_preview()
  previewing = false
  if debounce_timer then
    pcall(function() debounce_timer:stop(); debounce_timer:close() end)
    debounce_timer = nil
  end
  vim.api.nvim_clear_autocmds({ group = au_group })
  kill_preview_job()
  if preview_win and vim.api.nvim_win_is_valid(preview_win) then
    pcall(vim.api.nvim_win_close, preview_win, true)
  end
  clean_preview_buf()
  preview_win, netrw_win = nil, nil
end

local function show_preview(path, kind)
  if not preview_win or not vim.api.nvim_win_is_valid(preview_win) then
    close_preview()
    return
  end

  if not path then
    swap_preview_buf(preview_buf)
    return
  end

  local old = preview_buf
  local name = vim.fn.fnamemodify(path, ":t")
  local ext = ext_of(path)
  local w, h = preview_size()

  pcall(function() vim.wo[preview_win].statusline = " " .. name .. " " end)

  if kind == "dir" then
    if not swap_preview_buf(old) then return end
    local ok, entries = pcall(list_dir, path)
    if not ok then entries = {} end
    pcall(function()
      vim.wo[preview_win].statusline = (" %s/ (%d) "):format(name, #entries)
    end)
    vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false,
      #entries > 0 and entries or { "[empty]" })

  elseif image_exts[ext or ""] then
    if vim.fn.executable("chafa") == 0 then
      if not swap_preview_buf(old) then return end
      vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, { "need chafa for image preview" })
      return
    end
    if not swap_preview_buf(old) then return end
    preview_term({ "chafa", "--animate=off", "--polite=on", "--size=" .. w .. "x" .. h, path })

  elseif ext == "pdf" then
    if vim.fn.executable("pdftoppm") == 0 or vim.fn.executable("chafa") == 0 then
      if not swap_preview_buf(old) then return end
      vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, { "need poppler + chafa for pdf preview" })
      return
    end
    if not swap_preview_buf(old) then return end
    local tmp = os.tmpname() .. ".png"
    preview_term({ "sh", "-c", ("pdftoppm -f 1 -l 1 -png %s > %s && chafa --animate=off --polite=on --size=%dx%d %s || echo '[preview failed]'; rm -f %s"):format(
      vim.fn.shellescape(path), vim.fn.shellescape(tmp), w, h, vim.fn.shellescape(tmp), vim.fn.shellescape(tmp)) })

  elseif video_exts[ext or ""] then
    if vim.fn.executable("ffmpeg") == 0 or vim.fn.executable("chafa") == 0 then
      if not swap_preview_buf(old) then return end
      vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, { "need ffmpeg + chafa for video preview" })
      return
    end
    if not swap_preview_buf(old) then return end
    local tmp = os.tmpname() .. ".png"
    preview_term({ "sh", "-c", ("ffmpeg -v quiet -y -i %s -frames:v 1 %s && chafa --animate=off --polite=on --size=%dx%d %s || echo '[preview failed]'; rm -f %s"):format(
      vim.fn.shellescape(path), vim.fn.shellescape(tmp), w, h, vim.fn.shellescape(tmp), vim.fn.shellescape(tmp)) })

  else
    -- text file
    if not swap_preview_buf(old) then return end
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

local function schedule_preview()
  if not debounce_timer then
    debounce_timer = vim.uv.new_timer()
  end
  debounce_timer:stop()
  debounce_timer:start(30, 0, vim.schedule_wrap(function()
    if not previewing then return end
    if not netrw_win or not vim.api.nvim_win_is_valid(netrw_win) then return end
    if vim.api.nvim_get_current_win() ~= netrw_win then return end
    if vim.bo.filetype ~= "netrw" then return end
    pcall(show_preview, get_netrw_entry())
  end))
end

local function start_preview()
  if previewing then return end
  previewing = true
  netrw_win = vim.api.nvim_get_current_win()

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

  vim.api.nvim_set_current_win(netrw_win)

  vim.schedule(function()
    pcall(show_preview, get_netrw_entry())
  end)

  -- update preview on cursor move (debounced)
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = au_group,
    callback = function()
      if not previewing then return end
      schedule_preview()
    end,
  })

  -- rescale on resize
  vim.api.nvim_create_autocmd("VimResized", {
    group = au_group,
    callback = function()
      if previewing and preview_win and vim.api.nvim_win_is_valid(preview_win) then
        vim.api.nvim_win_set_width(preview_win, math.floor(vim.o.columns / 3))
      end
    end,
  })

  -- close when netrw is gone
  vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter" }, {
    group = au_group,
    callback = function()
      if not previewing then return end
      vim.schedule(function()
        if not previewing then return end
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          if vim.api.nvim_win_is_valid(win) then
            local buf = vim.api.nvim_win_get_buf(win)
            if vim.bo[buf].filetype == "netrw" then return end
          end
        end
        close_preview()
      end)
    end,
  })
end

local function try_xdg_open()
  local path, kind = get_netrw_entry()
  if not path or kind ~= "file" then return false end
  local ext = ext_of(path)
  if not ext or not external_exts[ext] then return false end
  vim.fn.jobstart({ "xdg-open", path }, { detach = true })
  return true
end

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

local function apply_netrw_settings()
  vim.g.netrw_sort_by = sort_mode
  if show_hidden then
    vim.g.netrw_list_hide = ""
    vim.g.netrw_hide = 0
  else
    vim.g.netrw_list_hide = "\\(^\\|\\s\\s\\)\\zs\\.[^.]\\S*"
    vim.g.netrw_hide = 1
  end
end

local function dir_item_count()
  local dir = vim.b.netrw_curdir
  if not dir then return 0 end
  local count = 0
  local handle = vim.uv.fs_scandir(dir)
  if not handle then return 0 end
  while true do
    local name = vim.uv.fs_scandir_next(handle)
    if not name then break end
    if show_hidden or not name:match("^%.") then
      count = count + 1
    end
  end
  return count
end

-- netrw statusline shows current dir + item count
vim.api.nvim_create_autocmd("FileType", {
  pattern = "netrw",
  callback = function()
    local count = dir_item_count()
    vim.wo.statusline = (" %%{b:netrw_curdir}  [%d]  sort:%s "):format(count, sort_mode)
  end,
})

-- netrw-only keymaps (fall through to default behavior in normal buffers)
local function netrw_map(key, fn, opts)
  opts = opts or {}
  opts.buffer = true
  vim.keymap.set("n", key, function()
    if vim.bo.filetype ~= "netrw" then
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, true, true), "n", false)
      return
    end
    fn()
  end, opts)
end

-- visual mode netrw map
local function netrw_vmap(key, fn, opts)
  opts = opts or {}
  opts.buffer = true
  vim.keymap.set("v", key, function()
    if vim.bo.filetype ~= "netrw" then
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, true, true), "n", false)
      return
    end
    vim.cmd("normal! \27") -- exit visual mode so '< '> are set
    fn()
  end, opts)
end

-- refresh netrw and update statusline
local function refresh_netrw()
  vim.cmd("edit .")
  vim.schedule(function()
    local count = dir_item_count()
    vim.wo.statusline = (" %%{b:netrw_curdir}  [%d]  sort:%s "):format(count, sort_mode)
  end)
end

-- track visited dirs for back navigation
local last_netrw_dir = nil
vim.api.nvim_create_autocmd("BufEnter", {
  callback = function()
    if vim.bo.filetype ~= "netrw" then return end
    local cur = vim.b.netrw_curdir
    if cur and cur ~= last_netrw_dir then
      if last_netrw_dir then
        table.insert(dir_history, last_netrw_dir)
        if #dir_history > 50 then table.remove(dir_history, 1) end
      end
      last_netrw_dir = cur
    end
  end,
})

-- init settings
apply_netrw_settings()

-- wire everything up when netrw loads
vim.api.nvim_create_autocmd("FileType", {
  pattern = "netrw",
  callback = function()
    if vim.b.netrw_custom_mapped then return end
    vim.b.netrw_custom_mapped = true

    vim.schedule(function()
      start_preview()

      -- trash (normal mode)
      netrw_map("D", function()
        local path = get_netrw_entry()
        if not path then return end
        local name = vim.fn.fnamemodify(path, ":t")
        if vim.fn.confirm("Trash " .. name .. "?", "&Yes\n&No") ~= 1 then return end
        trash_path(path)
        refresh_netrw()
      end)

      -- trash (visual mode)
      netrw_vmap("D", function()
        local entries = get_visual_entries()
        if #entries == 0 then return end
        if vim.fn.confirm("Trash " .. #entries .. " items?", "&Yes\n&No") ~= 1 then return end
        for _, path in ipairs(entries) do
          trash_path(path)
        end
        refresh_netrw()
      end)

      -- chmod (normal mode)
      netrw_map("C", function()
        local path = get_netrw_entry()
        if not path then return end
        local stat = vim.uv.fs_stat(path)
        if not stat then return end
        local current = ("%o"):format(stat.mode % 512)
        vim.ui.input({ prompt = "chmod: ", default = current }, function(mode)
          if not mode or mode == "" or mode == current then return end
          vim.fn.system({ "chmod", mode, path })
          refresh_netrw()
        end)
      end)

      -- chmod (visual mode)
      netrw_vmap("C", function()
        local entries = get_visual_entries()
        if #entries == 0 then return end
        vim.ui.input({ prompt = ("chmod %d files: "):format(#entries) }, function(mode)
          if not mode or mode == "" then return end
          for _, path in ipairs(entries) do
            vim.fn.system({ "chmod", mode, path })
          end
          refresh_netrw()
        end)
      end)

      -- toggle preview
      netrw_map("P", function()
        if previewing then
          close_preview()
        else
          start_preview()
        end
      end)

      -- toggle hidden files
      netrw_map(".", function()
        show_hidden = not show_hidden
        apply_netrw_settings()
        refresh_netrw()
      end)

      -- cycle sort mode: name -> time -> size -> name
      netrw_map("S", function()
        if sort_mode == "name" then
          sort_mode = "time"
        elseif sort_mode == "time" then
          sort_mode = "size"
        else
          sort_mode = "name"
        end
        apply_netrw_settings()
        refresh_netrw()
      end)

      -- bookmarks
      netrw_map("~", function()
        vim.cmd("edit " .. vim.fn.fnameescape(vim.fn.expand("~")))
      end)

      -- yank file contents to clipboard
      netrw_map("y", function()
        local path, kind = get_netrw_entry()
        if not path or kind ~= "file" then return end
        local mime = vim.fn.system({ "file", "-b", "--mime-type", path }):gsub("%s+$", "")
        if vim.v.shell_error ~= 0 or mime == "" then return end
        vim.fn.system({ "sh", "-c", "wl-copy --type " .. vim.fn.shellescape(mime) .. " < " .. vim.fn.shellescape(path) })
      end)

      -- quick rename
      netrw_map("r", function()
        local path = get_netrw_entry()
        if not path then return end
        local old_name = vim.fn.fnamemodify(path, ":t")
        vim.ui.input({ prompt = "Rename: ", default = old_name }, function(new_name)
          if not new_name or new_name == "" or new_name == old_name then return end
          vim.uv.fs_rename(path, vim.fn.fnamemodify(path, ":h") .. "/" .. new_name)
          refresh_netrw()
        end)
      end)

      -- new file or dir (end with / for dir)
      netrw_map("a", function()
        local dir = vim.b.netrw_curdir
        if not dir then return end
        dir = dir:gsub("/$", "")
        vim.ui.input({ prompt = "New (/ = dir): " }, function(name)
          if not name or name == "" then return end
          local full = dir .. "/" .. name
          if name:match("/$") then
            vim.fn.mkdir(full:gsub("/$", ""), "p")
          else
            vim.fn.mkdir(vim.fn.fnamemodify(full, ":h"), "p")
            vim.fn.writefile({}, full)
          end
          refresh_netrw()
        end)
      end)

      -- go back
      netrw_map("b", function()
        if #dir_history == 0 then return end
        vim.cmd("edit " .. vim.fn.fnameescape(table.remove(dir_history)))
      end, { nowait = true })

      -- enter opens media externally, everything else normally
      local orig_cr = vim.fn.maparg("<CR>", "n", false, true)
      netrw_map("<CR>", function()
        if not try_xdg_open() then
          if orig_cr and orig_cr.callback then
            orig_cr.callback()
          elseif orig_cr and orig_cr.rhs then
            vim.cmd("normal " .. vim.api.nvim_replace_termcodes(orig_cr.rhs, true, true, true))
          end
        end
      end)
    end)
  end,
})
