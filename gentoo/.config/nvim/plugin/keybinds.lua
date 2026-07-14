vim.keymap.set("t", "<Esc>", "<C-\\><C-n>")

-- compile & run
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

-- markdown markup highlights (vague doesn't define these)
vim.api.nvim_set_hl(0, "@markup.italic", { italic = true })
vim.api.nvim_set_hl(0, "@markup.strong", { bold = true })
vim.api.nvim_set_hl(0, "@markup.strikethrough", { strikethrough = true })

vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.opt_local.spell = true
    vim.opt_local.spelllang = "en_us"
    vim.opt_local.spellcapcheck = ""
    vim.opt_local.conceallevel = 2

    -- tab/shift-tab to indent/unindent bullets
    vim.keymap.set("n", "<Tab>", ">>", { buffer = true })
    vim.keymap.set("n", "<S-Tab>", "<<", { buffer = true })
    vim.keymap.set("i", "<S-Tab>", "<C-d>", { buffer = true })
  end,
})
