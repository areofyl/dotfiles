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

-- force 4-space tabs on all filetypes (override ftplugins)
vim.api.nvim_create_autocmd("FileType", {
  callback = function()
    vim.bo.tabstop = 4
    vim.bo.shiftwidth = 4
    vim.bo.expandtab = true
  end,
})

-- preserve indentation on blank lines when leaving insert mode
vim.api.nvim_create_autocmd("InsertLeavePre", {
  callback = function()
    local line = vim.api.nvim_get_current_line()
    if line:match("^%s+$") then
      -- mark it so we can restore after vim strips it
      vim.b._keep_indent_line = vim.fn.line(".")
      vim.b._keep_indent_text = line
    end
  end,
})

vim.api.nvim_create_autocmd("InsertLeave", {
  callback = function()
    local lnum = vim.b._keep_indent_line
    local text = vim.b._keep_indent_text
    if lnum and text then
      local cur = vim.fn.getline(lnum)
      if cur == "" then
        vim.fn.setline(lnum, text)
      end
    end
    vim.b._keep_indent_line = nil
    vim.b._keep_indent_text = nil
  end,
})

vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function() vim.hl.on_yank({ timeout = 150 }) end,
})

require("config.lazy")
vim.cmd.colorscheme("substrata")
