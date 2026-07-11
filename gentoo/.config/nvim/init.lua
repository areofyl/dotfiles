vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.scrolloff = 5
vim.opt.undofile = true
vim.opt.statusline = " %f %m%r%= %y %l:%c "
vim.opt.wrap = false

vim.g.netrw_banner = 0
vim.g.netrw_liststyle = 0
vim.g.netrw_keepdir = 0

vim.keymap.set("n", "<leader>e", function()
  local dir = vim.fn.expand("%:p:h")
  if dir == "" or vim.fn.isdirectory(dir) == 0 then
    dir = vim.fn.getcwd()
  end
  vim.cmd("Explore " .. vim.fn.fnameescape(dir))
end, { desc = "Open netrw in file's directory" })

require("config.lazy")

-- Change colorscheme here (e.g. "vim", "nimbus", "default")
vim.cmd.colorscheme("vim")

-- Quick todo: <leader>td opens ~/todo.md
vim.keymap.set("n", "<leader>td", "<cmd>edit ~/todo.md<cr>", { desc = "Open todo" })

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

-- :make — compile current C file
-- :Mr   — run binary (uses Makefile 'run' target if available, else ./binary)
vim.opt.makeprg = "cc %:S -o %:r:S"

vim.api.nvim_create_user_command("Mr", function()
  local has_makefile = vim.fn.filereadable("Makefile") == 1
  local cmd
  if has_makefile and vim.fn.system("grep -q '^run:' Makefile && echo y"):match("y") then
    cmd = "make run"
  else
    cmd = "./" .. vim.fn.expand("%:r")
  end
  vim.cmd("vertical botright split | term " .. cmd)
end, {})

vim.cmd("cabbrev mp MarkdownPreview")

vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.opt_local.spell = true
    vim.opt_local.spelllang = "en_us"
    vim.opt_local.spellcapcheck = ""
    vim.opt_local.conceallevel = 2
  end,
})
