local preview_win = nil
local preview_buf = nil
local netrw_win = nil
local au_group = vim.api.nvim_create_augroup("NetrwPreview", { clear = true })
local previewing = false
local dir_history = {}

local image_exts = {
  png = true, jpg = true, jpeg = true, gif = true,
  bmp = true, webp = true, svg = true, ico = true,
  tiff = true, tif = true,
}

local function is_image(path)
  local ext = path:match("%.(%w+)$")
  return ext and image_exts[ext:lower()]
end

local function is_pdf(path)
  local ext = path:match("%.(%w+)$")
  return ext and ext:lower() == "pdf"
end

local video_exts = {
  mp4 = true, mkv = true, webm = true, avi = true,
  mov = true, flv = true, wmv = true, m4v = true,
}

local function is_video(path)
  local ext = path:match("%.(%w+)$")
  return ext and video_exts[ext:lower()]
end

local function clean_preview_buf()
  if preview_buf and vim.api.nvim_buf_is_valid(preview_buf) then
    vim.api.nvim_buf_delete(preview_buf, { force = true })
  end
  preview_buf = nil
end

local function close_preview()
  previewing = false
  vim.api.nvim_clear_autocmds({ group = au_group })
  if preview_win and vim.api.nvim_win_is_valid(preview_win) then
    vim.api.nvim_win_close(preview_win, true)
  end
  clean_preview_buf()
  preview_win = nil
  netrw_win = nil
end

local function get_netrw_entry()
  local dir = vim.b.netrw_curdir
  if not dir then return nil, nil end
  local line = vim.trim(vim.api.nvim_get_current_line())
  if line == "" or line == "./" then return nil, nil end
  -- Strip tree-style markers (e.g. "│ ├─")
  line = line:gsub("^[│├└─┬ ]+", "")
  local is_dir = line:match("/$") ~= nil
  line = line:gsub("/$", "")
  if line == "" then return nil, nil end

  local path
  if line == ".." then
    path = vim.fn.fnamemodify((dir:gsub("/$", "")), ":h")
  else
    path = (dir:gsub("/$", "")) .. "/" .. line
  end

  if is_dir or line == ".." then
    if vim.fn.isdirectory(path) == 1 then return path, "dir" end
    return nil, nil
  end
  if vim.fn.filereadable(path) == 0 then return nil, nil end
  return path, "file"
end

local function list_dir(path)
  local entries = {}
  local handle = vim.loop.fs_scandir(path)
  if not handle then return entries end
  while true do
    local name, typ = vim.loop.fs_scandir_next(handle)
    if not name then break end
    if typ == "directory" then
      table.insert(entries, name .. "/")
    else
      table.insert(entries, name)
    end
  end
  table.sort(entries)
  return entries
end

local function file_info(path)
  local stat = vim.loop.fs_stat(path)
  if not stat then return nil end
  local size = stat.size
  local units = { "B", "K", "M", "G" }
  local i = 1
  while size >= 1024 and i < #units do
    size = size / 1024
    i = i + 1
  end
  local size_str = i == 1 and string.format("%d%s", size, units[i]) or string.format("%.1f%s", size, units[i])
  local perms = string.format("%o", stat.mode % 512)
  local mtime = os.date("%Y-%m-%d %H:%M", stat.mtime.sec)
  return perms .. "  " .. size_str .. "  " .. mtime
end

local function show_preview(path, kind)
  if not preview_win or not vim.api.nvim_win_is_valid(preview_win) then
    close_preview()
    return
  end

  if not path then
    local old = preview_buf
    preview_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(preview_win, preview_buf)
    if old and vim.api.nvim_buf_is_valid(old) then
      vim.api.nvim_buf_delete(old, { force = true })
    end
    return
  end

  local old = preview_buf

  -- Update preview statusline with filename
  local name = vim.fn.fnamemodify(path, ":t")
  vim.wo[preview_win].statusline = " " .. name .. " "

  if kind == "dir" then
    preview_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(preview_win, preview_buf)
    local entries = list_dir(path)
    vim.wo[preview_win].statusline = " " .. name .. "/ (" .. #entries .. ") "
    if #entries == 0 then
      entries = { "[empty directory]" }
    end
    vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, entries)
  elseif is_image(path) then
    if vim.fn.executable("chafa") == 0 then
      preview_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, { "install chafa to preview images" })
      vim.api.nvim_win_set_buf(preview_win, preview_buf)
      if old and old ~= preview_buf and vim.api.nvim_buf_is_valid(old) then
        vim.api.nvim_buf_delete(old, { force = true })
      end
      return
    end

    preview_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(preview_win, preview_buf)

    local win_width = vim.api.nvim_win_get_width(preview_win)
    local win_height = vim.api.nvim_win_get_height(preview_win)

    -- Focus preview win briefly to run termopen, then go back
    local cur_win = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(preview_win)
    vim.fn.termopen(string.format("chafa --size=%dx%d %s", win_width, win_height, vim.fn.shellescape(path)))
    vim.api.nvim_set_current_win(cur_win)
  elseif is_pdf(path) then
    if vim.fn.executable("pdftoppm") == 0 or vim.fn.executable("chafa") == 0 then
      preview_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, { "install poppler and chafa to preview PDFs" })
      vim.api.nvim_win_set_buf(preview_win, preview_buf)
      if old and old ~= preview_buf and vim.api.nvim_buf_is_valid(old) then
        vim.api.nvim_buf_delete(old, { force = true })
      end
      return
    end

    preview_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(preview_win, preview_buf)

    local win_width = vim.api.nvim_win_get_width(preview_win)
    local win_height = vim.api.nvim_win_get_height(preview_win)

    local cur_win = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(preview_win)
    vim.fn.termopen(string.format("pdftoppm -f 1 -l 1 -png %s | chafa --size=%dx%d", vim.fn.shellescape(path), win_width, win_height))
    vim.api.nvim_set_current_win(cur_win)
  elseif is_video(path) then
    if vim.fn.executable("ffmpeg") == 0 or vim.fn.executable("chafa") == 0 then
      preview_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, { "install ffmpeg and chafa to preview videos" })
      vim.api.nvim_win_set_buf(preview_win, preview_buf)
      if old and old ~= preview_buf and vim.api.nvim_buf_is_valid(old) then
        vim.api.nvim_buf_delete(old, { force = true })
      end
      return
    end

    preview_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(preview_win, preview_buf)

    local win_width = vim.api.nvim_win_get_width(preview_win)
    local win_height = vim.api.nvim_win_get_height(preview_win)

    local cur_win = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(preview_win)
    vim.fn.termopen(string.format("ffmpeg -v quiet -i %s -frames:v 1 -f image2pipe -vcodec png - | chafa --size=%dx%d", vim.fn.shellescape(path), win_width, win_height))
    vim.api.nvim_set_current_win(cur_win)
  else
    -- Text preview: just load the file in a readonly buffer
    preview_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(preview_win, preview_buf)

    -- Read file content
    local ok, lines = pcall(vim.fn.readfile, path, "", 200)
    if not ok or not lines then
      vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, { "[cannot read file]" })
      return
    end

    -- Check for binary
    for _, line in ipairs(lines) do
      if line:match("[%z\1-\8\14-\31]") then
        vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, { "[binary file]" })
        return
      end
    end

    local info = file_info(path)
    local header = info and { info, "" } or {}
    for i, l in ipairs(lines) do
      table.insert(header, l)
    end
    vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, header)

    local ft = vim.filetype.match({ filename = path, buf = preview_buf })
    if ft then
      vim.bo[preview_buf].filetype = ft
    end
  end

  if old and old ~= preview_buf and vim.api.nvim_buf_is_valid(old) then
    vim.api.nvim_buf_delete(old, { force = true })
  end
end

local function start_preview()
  if previewing then return end
  previewing = true
  netrw_win = vim.api.nvim_get_current_win()

  -- Open vertical split to the right, 1/3 screen width
  vim.cmd("botright vnew")
  preview_win = vim.api.nvim_get_current_win()
  preview_buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_win_set_width(preview_win, math.floor(vim.o.columns / 3))
  vim.wo[preview_win].number = false
  vim.wo[preview_win].relativenumber = false
  vim.wo[preview_win].signcolumn = "no"
  vim.wo[preview_win].statusline = " preview "
  vim.wo[preview_win].foldcolumn = "0"
  vim.wo[preview_win].winfixwidth = true

  -- Go back to netrw
  vim.api.nvim_set_current_win(netrw_win)

  -- Show initial preview (deferred so netrw settles)
  vim.schedule(function()
    local ok = pcall(show_preview, get_netrw_entry())
    if not ok then close_preview() end
  end)

  -- Update on cursor move
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = au_group,
    callback = function()
      if not previewing then return end
      if vim.api.nvim_get_current_win() ~= netrw_win then return end
      if vim.bo.filetype ~= "netrw" then return end
      local ok = pcall(show_preview, get_netrw_entry())
      if not ok then close_preview() end
    end,
  })

  -- Rescale on window resize
  vim.api.nvim_create_autocmd("VimResized", {
    group = au_group,
    callback = function()
      if not previewing then return end
      if preview_win and vim.api.nvim_win_is_valid(preview_win) then
        vim.api.nvim_win_set_width(preview_win, math.floor(vim.o.columns / 3))
      end
    end,
  })

  -- Close preview whenever we're no longer in netrw
  vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter" }, {
    group = au_group,
    callback = function()
      if not previewing then return end
      -- Check if any visible window still has netrw
      vim.schedule(function()
        if not previewing then return end
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          if vim.api.nvim_win_is_valid(win) then
            local buf = vim.api.nvim_win_get_buf(win)
            if vim.bo[buf].filetype == "netrw" then
              return
            end
          end
        end
        close_preview()
      end)
    end,
  })
end

-- Files to open externally with xdg-open
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

local function netrw_open_external()
  local path, kind = get_netrw_entry()
  if not path or kind ~= "file" then return false end
  local ext = path:match("%.(%w+)$")
  if not ext or not external_exts[ext:lower()] then return false end
  vim.fn.jobstart({ "xdg-open", path }, { detach = true })
  return true
end

-- Show current path in statusline for netrw
vim.api.nvim_create_autocmd("FileType", {
  pattern = "netrw",
  callback = function()
    vim.wo.statusline = " %{b:netrw_curdir} "
  end,
})

-- Restore 'a' in non-netrw buffers (netrw buffer reuse can leak the mapping)
vim.api.nvim_create_autocmd("BufEnter", {
  group = au_group,
  callback = function()
    if vim.bo.filetype ~= "netrw" then
      pcall(vim.keymap.del, "n", "a", { buffer = 0 })
    end
  end,
})

-- Track directory history
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

vim.api.nvim_create_autocmd("FileType", {
  pattern = "netrw",
  callback = function()
    vim.schedule(function()
      start_preview()
      -- Trash file
      local netrw_D = vim.fn.maparg("D", "n", false, true)
      vim.keymap.set("n", "D", function()
        local path, kind = get_netrw_entry()
        if not path then return end
        local trash = vim.fn.expand("~/.local/share/Trash/files")
        vim.fn.mkdir(trash, "p")
        local name = vim.fn.fnamemodify(path, ":t")
        local dest = trash .. "/" .. name
        -- Avoid overwriting existing trash
        local n = 1
        while vim.loop.fs_stat(dest) do
          dest = trash .. "/" .. name .. "." .. n
          n = n + 1
        end
        if vim.fn.confirm("Trash " .. name .. "?", "&Yes\n&No") == 1 then
          vim.loop.fs_rename(path, dest)
          vim.cmd("edit .")
        end
      end, { buffer = true, desc = "Trash file" })

      -- Bookmarks
      vim.keymap.set("n", "P", function()
        vim.cmd("edit " .. vim.fn.fnameescape(vim.fn.expand("~/Projects")))
      end, { buffer = true, desc = "Go to ~/Projects" })

      vim.keymap.set("n", "c", function()
        vim.cmd("edit " .. vim.fn.fnameescape(vim.fn.expand("~/.config")))
      end, { buffer = true, nowait = true, desc = "Go to ~/.config" })

      vim.keymap.set("n", "~", function()
        vim.cmd("edit " .. vim.fn.fnameescape(vim.fn.expand("~")))
      end, { buffer = true, desc = "Go to ~" })

      vim.keymap.set("n", "d", function()
        vim.cmd("edit " .. vim.fn.fnameescape(vim.fn.expand("~/Downloads")))
      end, { buffer = true, nowait = true, desc = "Go to ~/Downloads" })

      -- Yank file to clipboard
      vim.keymap.set("n", "y", function()
        local path, kind = get_netrw_entry()
        if path and kind == "file" then
          local mime = vim.fn.system({ "file", "-b", "--mime-type", path }):gsub("%s+$", "")
          vim.fn.system("wl-copy --type " .. vim.fn.shellescape(mime) .. " < " .. vim.fn.shellescape(path))
        end
      end, { buffer = true, desc = "Drag and drop file" })

      -- Quick rename
      vim.keymap.set("n", "r", function()
        local path, kind = get_netrw_entry()
        if not path then return end
        local old_name = vim.fn.fnamemodify(path, ":t")
        vim.ui.input({ prompt = "Rename: ", default = old_name }, function(new_name)
          if not new_name or new_name == "" or new_name == old_name then return end
          local dir = vim.fn.fnamemodify(path, ":h")
          vim.loop.fs_rename(path, dir .. "/" .. new_name)
          vim.cmd("edit .")
        end)
      end, { buffer = true, desc = "Rename file" })

      -- New file or directory (trailing / = dir)
      vim.keymap.set("n", "a", function()
        local dir = vim.b.netrw_curdir
        if not dir then return end
        dir = dir:gsub("/$", "")
        vim.ui.input({ prompt = "New (end with / for dir): " }, function(name)
          if not name or name == "" then return end
          local full = dir .. "/" .. name
          if name:match("/$") then
            vim.fn.mkdir(full:gsub("/$", ""), "p")
          else
            local parent = vim.fn.fnamemodify(full, ":h")
            if vim.fn.isdirectory(parent) == 0 then
              vim.fn.mkdir(parent, "p")
            end
            vim.fn.writefile({}, full)
          end
          vim.cmd("edit .")
        end)
      end, { buffer = true, desc = "New file/dir" })

      -- Back history
      vim.keymap.set("n", "b", function()
        if #dir_history == 0 then return end
        local prev = table.remove(dir_history)
        vim.cmd("edit " .. vim.fn.fnameescape(prev))
      end, { buffer = true, nowait = true, desc = "Go back" })

      local netrw_cr = vim.fn.maparg("<CR>", "n", false, true)
      vim.keymap.set("n", "<CR>", function()
        if not netrw_open_external() then
          if netrw_cr and netrw_cr.callback then
            netrw_cr.callback()
          elseif netrw_cr and netrw_cr.rhs then
            vim.cmd("normal " .. vim.api.nvim_replace_termcodes(netrw_cr.rhs, true, true, true))
          end
        end
      end, { buffer = true })
    end)
  end,
})
