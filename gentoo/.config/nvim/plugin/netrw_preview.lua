local preview_win = nil
local preview_buf = nil
local netrw_win = nil
local au_group = vim.api.nvim_create_augroup("NetrwPreview", { clear = true })
local previewing = false

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

  if kind == "dir" then
    preview_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(preview_win, preview_buf)
    local entries = list_dir(path)
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

    vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, lines)

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

-- Open files with external programs when appropriate
local open_externally = {
  png = "imv", jpg = "imv", jpeg = "imv", gif = "imv",
  bmp = "imv", webp = "imv", svg = "imv", tiff = "imv", tif = "imv",
  pdf = "zathura",
  mp4 = "mpv", mkv = "mpv", webm = "mpv", avi = "mpv",
  mp3 = "mpv", flac = "mpv", ogg = "mpv", wav = "mpv",
}

local function netrw_open_external()
  local dir = vim.b.netrw_curdir
  if not dir then return false end
  local line = vim.trim(vim.api.nvim_get_current_line())
  if line == "" or line == "../" or line == "./" or line:match("/$") then return false end
  line = line:gsub("^[│├└─┬ ]+", "")
  local ext = line:match("%.(%w+)$")
  if not ext then return false end
  local prog = open_externally[ext:lower()]
  if not prog then return false end
  if vim.fn.executable(prog) == 0 then return false end
  local path = (dir:gsub("/$", "")) .. "/" .. line
  vim.fn.jobstart({ prog, path }, { detach = true })
  return true
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "netrw",
  callback = function()
    vim.schedule(function()
      start_preview()
      -- Dragon drag-and-drop
      vim.keymap.set("n", "D", function()
        local path, kind = get_netrw_entry()
        if path and kind == "file" then
          vim.fn.jobstart({ "dragon", "--and-exit", path }, { detach = true })
        end
      end, { buffer = true, desc = "Drag and drop file" })

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
