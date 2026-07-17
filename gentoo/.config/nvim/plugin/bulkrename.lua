local function do_rename(buf, dir, original)
  local new = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  if #new ~= #original then
    vim.notify("Line count changed — add/delete files is not supported", vim.log.levels.ERROR)
    return false
  end

  local ops = {}
  for i, old_name in ipairs(original) do
    local new_name = new[i]
    if new_name ~= old_name and new_name ~= "" then
      table.insert(ops, { old = dir .. "/" .. old_name, new = dir .. "/" .. new_name })
    end
  end

  if #ops == 0 then
    vim.notify("No changes")
    vim.bo[buf].modified = false
    return true
  end

  -- Show preview
  local preview = { "Bulk rename operations:" }
  for _, op in ipairs(ops) do
    table.insert(preview, "  " .. op.old .. " -> " .. op.new)
  end
  table.insert(preview, "Apply? [y/N]")
  vim.api.nvim_echo({{ table.concat(preview, "\n") }}, false, {})

  local ok = vim.fn.nr2char(vim.fn.getchar())
  if ok ~= "y" and ok ~= "Y" then
    vim.notify("Cancelled")
    return false
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
  vim.bo[buf].modified = false
  return true
end

local function scan_dir(dir)
  local entries = {}
  local handle = vim.uv.fs_scandir(dir)
  if not handle then return entries end
  while true do
    local name, typ = vim.uv.fs_scandir_next(handle)
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

local function bulk_rename(dir, from_netrw)
  dir = dir or vim.fn.expand("%:p:h")
  if dir == "" then dir = vim.fn.getcwd() end
  dir = dir:gsub("/$", "")

  local entries = scan_dir(dir)
  local original = vim.deepcopy(entries)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, entries)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_name(buf, "bulkrename://" .. dir)
  vim.bo[buf].buftype = "acwrite"
  vim.bo[buf].modified = false

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = function()
      if do_rename(buf, dir, original) then
        if from_netrw then
          vim.api.nvim_buf_delete(buf, { force = true })
          vim.cmd("Explore " .. vim.fn.fnameescape(dir))
        else
          -- Refresh
          local refreshed = scan_dir(dir)
          original = refreshed
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, refreshed)
          vim.bo[buf].modified = false
        end
      end
    end,
  })

  -- Flatten: move all contents of dir under cursor up, remove empty dir
  vim.keymap.set("n", "X", function()
    local line = vim.api.nvim_get_current_line()
    if not line:match("/$") then
      vim.notify("Not a directory", vim.log.levels.WARN)
      return
    end
    local subdir_name = line:gsub("/$", "")
    local subdir_path = dir .. "/" .. subdir_name
    local contents = scan_dir(subdir_path)
    if #contents == 0 then
      vim.fn.delete(subdir_path, "d")
      vim.notify("Removed empty directory: " .. subdir_name)
    else
      local moved = 0
      for _, entry in ipairs(contents) do
        local old = subdir_path .. "/" .. entry
        local new = dir .. "/" .. entry
        if vim.uv.fs_stat(new) then
          vim.notify("Skipped (already exists): " .. entry, vim.log.levels.WARN)
        else
          if vim.uv.fs_rename(old, new) then
            moved = moved + 1
          else
            vim.notify("Failed to move: " .. entry, vim.log.levels.ERROR)
          end
        end
      end
      vim.fn.delete(subdir_path, "rf")
      vim.notify(moved .. " file(s) released from " .. subdir_name)
    end
    -- Refresh buffer
    local refreshed = scan_dir(dir)
    original = refreshed
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, refreshed)
    vim.bo[buf].modified = false
  end, { buffer = buf, desc = "Flatten directory" })

  if from_netrw then
    vim.keymap.set("n", "q", function()
      vim.api.nvim_buf_delete(buf, { force = true })
      vim.cmd("Explore " .. vim.fn.fnameescape(dir))
    end, { buffer = buf, desc = "Back to netrw" })
  end
end

vim.api.nvim_create_user_command("Bulkrename", function(opts)
  bulk_rename(opts.args ~= "" and opts.args or nil)
end, { nargs = "?", complete = "dir" })

vim.api.nvim_create_autocmd("FileType", {
  pattern = "netrw",
  callback = function()
    vim.keymap.set("n", "B", function()
      local dir = vim.b.netrw_curdir
      bulk_rename(dir, true)
    end, { buffer = true, desc = "Bulk rename" })
  end,
})
