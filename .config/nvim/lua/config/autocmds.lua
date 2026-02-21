-- Start in insert mode when opening a new empty file
vim.api.nvim_create_autocmd("BufNewFile", {
  callback = function()
    vim.cmd("startinsert")
  end,
})

-- Highlight on yank
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.highlight.on_yank({ timeout = 200 })
  end,
})

-- :run command — compile and run C/C++ in a vertical split
vim.api.nvim_create_user_command("Run", function()
  local file = vim.fn.expand("%:p")
  local ext = vim.fn.expand("%:e")
  local name = vim.fn.expand("%:p:r")

  local compiler
  if ext == "c" then
    compiler = "gcc"
  elseif ext == "cpp" or ext == "cc" or ext == "cxx" then
    compiler = "g++"
  else
    vim.notify("run: unsupported filetype ." .. ext, vim.log.levels.WARN)
    return
  end

  -- find a free output name (filename, filename1, filename2, ...)
  local out = name
  local i = 1
  while vim.fn.filereadable(out) == 1 do
    out = name .. i
    i = i + 1
  end

  -- save the file first
  vim.cmd("silent write")

  -- compile and run in a vertical split (side by side)
  local term_buf = vim.api.nvim_create_buf(false, true)
  vim.cmd("vsplit")
  local term_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(term_win, term_buf)
  vim.fn.termopen(
    compiler .. " " .. vim.fn.shellescape(file) .. " -o " .. vim.fn.shellescape(out)
      .. " && " .. vim.fn.shellescape(out),
    {
      on_exit = function(_, code)
        vim.schedule(function()
          if not vim.api.nvim_buf_is_valid(term_buf) then return end
          -- switch to normal mode and map q to close the split
          vim.api.nvim_buf_set_keymap(term_buf, "n", "q", "", {
            noremap = true, silent = true,
            callback = function()
              if vim.api.nvim_win_is_valid(term_win) then
                vim.api.nvim_win_close(term_win, true)
              end
              if vim.api.nvim_buf_is_valid(term_buf) then
                vim.api.nvim_buf_delete(term_buf, { force = true })
              end
            end,
          })
          -- exit terminal mode so q works
          pcall(vim.api.nvim_feedkeys, vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
          if code ~= 0 then
            vim.notify("run: exited with code " .. code .. " — press q to close", vim.log.levels.WARN)
          else
            vim.notify("run: finished — press q to close", vim.log.levels.INFO)
          end
        end)
      end,
    }
  )
  vim.cmd("startinsert")
end, {})
-- allow lowercase :run to trigger :Run
vim.cmd("cnoreabbrev run Run")
