vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.scrolloff = 5
vim.opt.undofile = true
vim.opt.swapfile = false
vim.opt.wrap = false
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.statusline = " %f %m%r%= %y %l:%c "
vim.opt.termguicolors = true
vim.opt.signcolumn = "yes"
vim.opt.completeopt = "menu,menuone,noselect,popup"
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.cursorline = true
vim.opt.updatetime = 250

vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function() vim.hl.on_yank({ timeout = 150 }) end,
})

require("config.lazy")
vim.cmd.colorscheme("vague")

vim.api.nvim_set_hl(0, "@markup.heading.1.markdown", { fg = "#ebcb8b", bold = true })
vim.api.nvim_set_hl(0, "@markup.heading.2.markdown", { fg = "#a3be8c", bold = true })
vim.api.nvim_set_hl(0, "@markup.list.markdown", { fg = "#81a1c1" })
