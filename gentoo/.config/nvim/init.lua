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
vim.opt.statusline = " %f %m%r%= %y %l:%c "
vim.opt.termguicolors = true
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

-- preserve whitespace-only lines on save (runs after LSP format)
vim.api.nvim_create_autocmd("BufWritePost", {
  callback = function()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local changed = false
    for i, line in ipairs(lines) do
      if line == "" then
        local prev_indent = (lines[i - 1] or ""):match("^([\t ]+)")
        local next_indent = (lines[i + 1] or ""):match("^([\t ]+)")
        local indent = prev_indent or next_indent
        if indent then
          lines[i] = indent
          changed = true
        end
      end
    end
    if changed then
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.cmd("noautocmd write")
    end
  end,
})

vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function() vim.hl.on_yank({ timeout = 150 }) end,
})

require("config.lazy")
vim.cmd.colorscheme("substrata")
