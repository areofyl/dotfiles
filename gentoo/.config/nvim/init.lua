vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
vim.opt.number = true
vim.opt.relativenumber = true
require("config.lazy")

-- Change colorscheme here (e.g. "vim", "nimbus", "default")
vim.cmd.colorscheme("vim")

-- Terminal: <C-t> toggles a bottom split terminal
vim.keymap.set("n", "<C-t>", function()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].buftype == "terminal" then
      vim.api.nvim_win_close(win, true)
      return
    end
  end
  vim.cmd("botright 15split | term")
end, { desc = "Toggle terminal" })
vim.keymap.set("t", "<C-t>", "<cmd>close<cr>", { desc = "Close terminal" })
vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- C compile/run commands
-- :Cc  — compile current file (cc file.c -o file)
-- :Cr  — run the compiled binary (./file)
-- :Ccr — compile and run
local function c_out()
  return vim.fn.expand("%:r")
end

vim.api.nvim_create_user_command("Cc", function()
  vim.cmd("write")
  vim.cmd("botright 15split | term cc " .. vim.fn.expand("%") .. " -o " .. c_out())
end, {})

vim.api.nvim_create_user_command("Cr", function()
  vim.cmd("botright 15split | term ./" .. c_out())
end, {})

vim.api.nvim_create_user_command("Ccr", function()
  vim.cmd("write")
  vim.cmd("botright 15split | term cc " .. vim.fn.expand("%") .. " -o " .. c_out() .. " && ./" .. c_out())
end, {})

vim.cmd("cabbrev cc Cc")
vim.cmd("cabbrev cr Cr")
vim.cmd("cabbrev ccr Ccr")
