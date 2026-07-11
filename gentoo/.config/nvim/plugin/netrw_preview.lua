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

local function get_netrw_file()
  local dir = vim.b.netrw_curdir
  if not dir then return nil end
  local line = vim.trim(vim.api.nvim_get_current_line())
  if line == "" or line == "../" or line == "./" then return nil end
  -- Strip tree-style markers (e.g. "│ ├─")
  line = line:gsub("^[│├└─┬ ]+", "")
  line = line:gsub("/$", "")
  if line == "" then return nil end
  local path = (dir:gsub("/$", "")) .. "/" .. line
  if vim.fn.isdirectory(path) == 1 then return nil end
  if vim.fn.filereadable(path) == 0 then return nil end
  return path
end

local function show_preview(path)
  if not path then
    -- Show empty buffer when no file to preview
    if preview_win and vim.api.nvim_win_is_valid(preview_win) then
      clean_preview_buf()
      preview_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_win_set_buf(preview_win, preview_buf)
    end
    return
  end

  if not preview_win or not vim.api.nvim_win_is_valid(preview_win) then
    close_preview()
    return
  end

  clean_preview_buf()

  if is_image(path) then
    if vim.fn.executable("chafa") == 0 then
      preview_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, { "install chafa to preview images" })
      vim.api.nvim_win_set_buf(preview_win, preview_buf)
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
end

local function start_preview()
  if previewing then return end
  previewing = true
  netrw_win = vim.api.nvim_get_current_win()

  -- Open vertical split to the right
  vim.cmd("botright vnew")
  preview_win = vim.api.nvim_get_current_win()
  preview_buf = vim.api.nvim_get_current_buf()
  vim.wo[preview_win].number = false
  vim.wo[preview_win].relativenumber = false
  vim.wo[preview_win].signcolumn = "no"
  vim.wo[preview_win].foldcolumn = "0"
  vim.wo[preview_win].winfixwidth = true

  -- Go back to netrw
  vim.api.nvim_set_current_win(netrw_win)

  local netrw_buf = vim.api.nvim_get_current_buf()

  -- Show initial preview (deferred so netrw settles)
  vim.schedule(function()
    local ok = pcall(show_preview, get_netrw_file())
    if not ok then close_preview() end
  end)

  -- Update on cursor move (not buffer-specific so it survives netrw dir changes)
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = au_group,
    callback = function()
      if not previewing then return end
      if vim.api.nvim_get_current_win() ~= netrw_win then return end
      if vim.bo.filetype ~= "netrw" then return end
      local ok = pcall(show_preview, get_netrw_file())
      if not ok then close_preview() end
    end,
  })

  -- Clean up when leaving netrw (but not when opening the preview split)
  vim.api.nvim_create_autocmd("WinEnter", {
    group = au_group,
    callback = function()
      if not previewing then return end
      local cur_win = vim.api.nvim_get_current_win()
      if cur_win ~= netrw_win and cur_win ~= preview_win then
        close_preview()
      end
    end,
  })
end

local function toggle_preview()
  if previewing then
    close_preview()
  else
    start_preview()
  end
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "netrw",
  callback = function()
    vim.schedule(function()
      vim.keymap.set("n", "P", toggle_preview, { buffer = true, desc = "Toggle preview" })
    end)
  end,
})
