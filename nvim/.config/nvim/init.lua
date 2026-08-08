vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- disable netrw (fm.lua replaces it hehe)
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_netrw = 1

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.scrolloff = 999
vim.opt.undofile = true
vim.opt.swapfile = false
vim.opt.wrap = false
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.statusline = " %f %m%r%=%{%v:lua.eldoc_statusline()%}%= %y %l:%c "
vim.opt.signcolumn = "yes"
vim.opt.completeopt = "menu,menuone,noselect,popup"
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.cursorline = true
vim.opt.updatetime = 250

-- force 4-wide tabs on all filetypes (override ftplugins)
vim.api.nvim_create_autocmd("FileType", {
  callback = function()
    vim.bo.tabstop = 4
    vim.bo.shiftwidth = 4
  end,
})

vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function() vim.hl.on_yank({ timeout = 150 }) end,
})

require("config.lazy")
vim.cmd.colorscheme("modus_vivendi")
