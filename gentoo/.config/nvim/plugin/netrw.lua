-- netrw config + file browser enhancements
-- preview pane, bookmarks, trash, rename, clipboard yank

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

-- file type checks

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

-- get the file/dir under cursor in netrw

local function get_netrw_entry()
  local dir = vim.b.netrw_curdir
  if not dir then return nil, nil end

  local line = vim.trim(vim.api.nvim_get_current_line())
  if line == "" or line == "./" then return nil, nil end

  line = line:gsub("^[│├└─┬ ]+", "") -- strip tree markers
  local is_dir = line:match("/$") ~= nil
  line = line:gsub("/$", "")
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

-- directory listing for preview

local function list_dir(path)
  local entries = {}
  local handle = vim.loop.fs_scandir(path)
  if not handle then return entries end
  while true do
    local name, typ = vim.loop.fs_scandir_next(handle)
    if not name then break end
    table.insert(entries, typ == "directory" and name .. "/" or name)
  end
  table.sort(entries)
  return entries
end

-- file metadata line

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

  local size_str = i == 1 and ("%d%s"):format(size, units[i]) or ("%.1f%s"):format(size, units[i])
  local perms = ("%o"):format(stat.mode % 512)
  local mtime = os.date("%Y-%m-%d %H:%M", stat.mtime.sec)
  return perms .. "  " .. size_str .. "  " .. mtime
end

-- swap preview buffer without closing the window

local function swap_preview_buf(old)
  preview_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(preview_win, preview_buf)
  if old and old ~= preview_buf and vim.api.nvim_buf_is_valid(old) then
    vim.api.nvim_buf_delete(old, { force = true })
  end
end

-- run a command in the preview pane (for chafa, ffmpeg, etc)

local function preview_term(cmd)
  local cur = vim.api.nvim_get_current_win()
  vim.api.nvim_set_current_win(preview_win)
  vim.fn.termopen(cmd)
  vim.api.nvim_set_current_win(cur)
end

local function preview_size()
  return vim.api.nvim_win_get_width(preview_win), vim.api.nvim_win_get_height(preview_win)
end

-- cleanup

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
  preview_win, netrw_win = nil, nil
end

-- the actual preview logic

local function show_preview(path, kind)
  if not preview_win or not vim.api.nvim_win_is_valid(preview_win) then
    close_preview()
    return
  end

  -- nothing to preview
  if not path then
    swap_preview_buf(preview_buf)
    return
  end

  local old = preview_buf
  local name = vim.fn.fnamemodify(path, ":t")
  local ext = ext_of(path)
  local w, h = preview_size()

  vim.wo[preview_win].statusline = " " .. name .. " "

  if kind == "dir" then
    swap_preview_buf(old)
    local entries = list_dir(path)
    vim.wo[preview_win].statusline = (" %s/ (%d) "):format(name, #entries)
    vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false,
      #entries > 0 and entries or { "[empty]" })

  elseif image_exts[ext or ""] then
    if vim.fn.executable("chafa") == 0 then
      swap_preview_buf(old)
      vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, { "need chafa for image preview" })
      return
    end
    swap_preview_buf(old)
    preview_term(("chafa --size=%dx%d %s"):format(w, h, vim.fn.shellescape(path)))

  elseif ext == "pdf" then
    if vim.fn.executable("pdftoppm") == 0 or vim.fn.executable("chafa") == 0 then
      swap_preview_buf(old)
      vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, { "need poppler + chafa for pdf preview" })
      return
    end
    swap_preview_buf(old)
    preview_term(("pdftoppm -f 1 -l 1 -png %s | chafa --size=%dx%d"):format(
      vim.fn.shellescape(path), w, h))

  elseif video_exts[ext or ""] then
    if vim.fn.executable("ffmpeg") == 0 or vim.fn.executable("chafa") == 0 then
      swap_preview_buf(old)
      vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, { "need ffmpeg + chafa for video preview" })
      return
    end
    swap_preview_buf(old)
    preview_term(("ffmpeg -v quiet -i %s -frames:v 1 -f image2pipe -vcodec png - | chafa --size=%dx%d"):format(
      vim.fn.shellescape(path), w, h))

  else
    -- text file
    swap_preview_buf(old)
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

    local ft = vim.filetype.match({ filename = path, buf = preview_buf })
    if ft then vim.bo[preview_buf].filetype = ft end
  end
end

-- open the preview pane and wire up autocmds

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

  -- update preview on cursor move
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = au_group,
    callback = function()
      if not previewing then return end
      if vim.api.nvim_get_current_win() ~= netrw_win then return end
      if vim.bo.filetype ~= "netrw" then return end
      pcall(show_preview, get_netrw_entry())
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

-- xdg-open for media/docs

local function try_xdg_open()
  local path, kind = get_netrw_entry()
  if not path or kind ~= "file" then return false end
  local ext = ext_of(path)
  if not ext or not external_exts[ext] then return false end
  vim.fn.jobstart({ "xdg-open", path }, { detach = true })
  return true
end

-- netrw statusline shows current dir
vim.api.nvim_create_autocmd("FileType", {
  pattern = "netrw",
  callback = function()
    vim.wo.statusline = " %{b:netrw_curdir} "
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

-- wire everything up when netrw loads
vim.api.nvim_create_autocmd("FileType", {
  pattern = "netrw",
  callback = function()
    vim.schedule(function()
      start_preview()

      -- trash instead of delete
      netrw_map("D", function()
        local path = get_netrw_entry()
        if not path then return end
        local trash = vim.fn.expand("~/.local/share/Trash/files")
        vim.fn.mkdir(trash, "p")
        local name = vim.fn.fnamemodify(path, ":t")
        local dest = trash .. "/" .. name
        local n = 1
        while vim.loop.fs_stat(dest) do
          dest = trash .. "/" .. name .. "." .. n
          n = n + 1
        end
        if vim.fn.confirm("Trash " .. name .. "?", "&Yes\n&No") == 1 then
          vim.loop.fs_rename(path, dest)
          vim.cmd("edit .")
        end
      end)

      -- bookmarks
      netrw_map("P", function()
        vim.cmd("edit " .. vim.fn.fnameescape(vim.fn.expand("~/Projects")))
      end)
      netrw_map("c", function()
        vim.cmd("edit " .. vim.fn.fnameescape(vim.fn.expand("~/.config")))
      end, { nowait = true })
      netrw_map("~", function()
        vim.cmd("edit " .. vim.fn.fnameescape(vim.fn.expand("~")))
      end)
      netrw_map("d", function()
        vim.cmd("edit " .. vim.fn.fnameescape(vim.fn.expand("~/Downloads")))
      end, { nowait = true })

      -- yank file contents to clipboard
      netrw_map("y", function()
        local path, kind = get_netrw_entry()
        if path and kind == "file" then
          local mime = vim.fn.system({ "file", "-b", "--mime-type", path }):gsub("%s+$", "")
          vim.fn.system("wl-copy --type " .. vim.fn.shellescape(mime) .. " < " .. vim.fn.shellescape(path))
        end
      end)

      -- quick rename
      netrw_map("r", function()
        local path = get_netrw_entry()
        if not path then return end
        local old_name = vim.fn.fnamemodify(path, ":t")
        vim.ui.input({ prompt = "Rename: ", default = old_name }, function(new_name)
          if not new_name or new_name == "" or new_name == old_name then return end
          vim.loop.fs_rename(path, vim.fn.fnamemodify(path, ":h") .. "/" .. new_name)
          vim.cmd("edit .")
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
          vim.cmd("edit .")
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
