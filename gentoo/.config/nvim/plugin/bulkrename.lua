local function bulk_rename(dir, from_netrw)
  dir = dir or vim.fn.expand("%:p:h")
  if dir == "" then dir = vim.fn.getcwd() end
  dir = dir:gsub("/$", "")

  local entries = {}
  local handle = vim.loop.fs_scandir(dir)
  if not handle then
    vim.notify("Cannot read directory: " .. dir, vim.log.levels.ERROR)
    return
  end

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

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, entries)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_name(buf, "bulkrename://" .. dir)
  vim.bo[buf].buftype = "acwrite"
  vim.bo[buf].modified = false

  -- Override :wq/:x to write then reopen netrw instead of quitting
  if from_netrw then
    vim.api.nvim_buf_create_user_command(buf, "wq", function()
      vim.cmd("write")
      vim.cmd("Explore " .. vim.fn.fnameescape(dir))
    end, {})
    vim.api.nvim_buf_create_user_command(buf, "x", function()
      vim.cmd("write")
      vim.cmd("Explore " .. vim.fn.fnameescape(dir))
    end, {})
    vim.keymap.set("n", "q", function()
      vim.cmd("Explore " .. vim.fn.fnameescape(dir))
    end, { buffer = buf, desc = "Back to netrw" })
  end

  local original = vim.deepcopy(entries)

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = function()
      local new = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

      if #new ~= #original then
        vim.notify("Line count changed — add/delete files is not supported", vim.log.levels.ERROR)
        return
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
        return
      end

      -- Show preview
      local preview = { "Bulk rename operations:" }
      for _, op in ipairs(ops) do
        table.insert(preview, "  " .. op.old .. " -> " .. op.new)
      end
      table.insert(preview, "Apply? [y/N]")
      vim.api.nvim_echo({{table.concat(preview, "\n")}}, false, {})

      local ok = vim.fn.nr2char(vim.fn.getchar())
      if ok ~= "y" and ok ~= "Y" then
        vim.notify("Cancelled")
        return
      end

      for _, op in ipairs(ops) do
        -- mkdir -p for parent directory if needed
        local parent = vim.fn.fnamemodify(op.new, ":h")
        if vim.fn.isdirectory(parent) == 0 then
          vim.fn.mkdir(parent, "p")
        end
        local ret = vim.loop.fs_rename(op.old, op.new)
        if not ret then
          vim.notify("Failed: " .. op.old .. " -> " .. op.new, vim.log.levels.ERROR)
        end
      end

      vim.notify(#ops .. " file(s) renamed")
      vim.bo[buf].modified = false


      -- Refresh the buffer with new state
      local refreshed = {}
      handle = vim.loop.fs_scandir(dir)
      if handle then
        while true do
          local name, typ = vim.loop.fs_scandir_next(handle)
          if not name then break end
          if typ == "directory" then
            table.insert(refreshed, name .. "/")
          else
            table.insert(refreshed, name)
          end
        end
      end
      table.sort(refreshed)
      original = refreshed
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, refreshed)
      vim.bo[buf].modified = false
    end,
  })
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
