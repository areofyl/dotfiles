vim.keymap.set("t", "<Esc>", "<C-\\><C-n>")

-- compile & run
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "c", "cpp" },
  callback = function()
    vim.opt_local.makeprg = "cc %:S -o %:r:S"
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "python",
  callback = function()
    vim.opt_local.makeprg = "python3 %:S"
  end,
})

vim.keymap.set("n", "<leader>m", "<cmd>make<CR>", { desc = "Make" })

vim.api.nvim_create_user_command("Mr", function()
  local has_makefile = vim.fn.filereadable("Makefile") == 1
  local cmd
  if has_makefile and vim.fn.system("grep -q '^run:' Makefile && echo y"):match("y") then
    cmd = "make run"
  else
    local ft = vim.bo.filetype
    if ft == "python" then
      cmd = "python3 " .. vim.fn.expand("%:S")
    else
      cmd = "./" .. vim.fn.expand("%:r")
    end
  end
  vim.cmd("vertical botright split | term " .. cmd)
end, {})

-- markdown markup highlights (vague doesn't define these)
vim.api.nvim_set_hl(0, "@markup.italic", { italic = true })
vim.api.nvim_set_hl(0, "@markup.strong", { bold = true })
vim.api.nvim_set_hl(0, "@markup.strikethrough", { strikethrough = true })

-- title case helper (ignores small words unless first)
local small_words = {
  a=1, an=1, the=1, ["and"]=1, but=1, ["or"]=1, nor=1, ["for"]=1,
  yet=1, so=1, ["in"]=1, on=1, at=1, to=1, by=1, of=1, up=1,
  is=1, as=1, it=1, vs=1, via=1, per=1, ["if"]=1, ["do"]=1,
}

local function title_case(str)
  local words = {}
  for w in str:gmatch("%S+") do table.insert(words, w) end
  for i, w in ipairs(words) do
    if i == 1 or not small_words[w:lower()] then
      words[i] = w:sub(1,1):upper() .. w:sub(2)
    else
      words[i] = w:lower()
    end
  end
  return table.concat(words, " ")
end

local md_group = vim.api.nvim_create_augroup("MarkdownSettings", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
  group = md_group,
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

    -- heading navigation
    vim.keymap.set("n", "]]", function()
      vim.fn.search("^#", "W")
    end, { buffer = true, desc = "Next heading" })
    vim.keymap.set("n", "[[", function()
      vim.fn.search("^#", "bW")
    end, { buffer = true, desc = "Previous heading" })

    -- follow markdown link under cursor (handles [text](path) and [[wiki-style]])
    vim.keymap.set("n", "gf", function()
      local line = vim.api.nvim_get_current_line()
      local col = vim.fn.col(".")

      -- [text](path.md)
      for link in line:gmatch("%[.-%]%((.-)%)") do
        local s, e = line:find("%[.-%]%(" .. vim.pesc(link) .. "%)")
        if s and col >= s and col <= e then
          if not link:match("^https?://") then
            vim.cmd("edit " .. vim.fn.fnameescape(link))
          else
            vim.fn.jobstart({ "xdg-open", link }, { detach = true })
          end
          return
        end
      end

      -- [[wiki-link]]
      for link in line:gmatch("%[%[(.-)%]%]") do
        local s, e = line:find("%[%[" .. vim.pesc(link) .. "%]%]")
        if s and col >= s and col <= e then
          local path = link:gsub(" ", "-") .. ".md"
          vim.cmd("edit " .. vim.fn.fnameescape(path))
          return
        end
      end

      -- fallback to normal gf
      vim.cmd("normal! gF")
    end, { buffer = true, desc = "Follow link" })

    -- word count in statusline for markdown
    vim.opt_local.statusline = " %f %m%r%= %{wordcount().words}w %y %l:%c "

    -- *<space> at start of line = indented sub-bullet
    -- -<space> at start of line = top-level bullet
    vim.keymap.set("i", "<Space>", function()
      local line = vim.api.nvim_get_current_line()
      local col = vim.fn.col(".")
      if line:match("^%s*%*$") and col == #line + 1 then
        return "<C-u>* "
      elseif line:match("^%s*%-$") and col == #line + 1 then
        return "<C-u>- "
      end
      return " "
    end, { buffer = true, expr = true, replace_keycodes = true })
  end,
})

-- title case headers on save (once per buffer, not per FileType event)
vim.api.nvim_create_autocmd("BufWritePre", {
  group = md_group,
  pattern = "*.md",
  callback = function()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    for i, line in ipairs(lines) do
      local hashes, text = line:match("^(#+)%s+(.+)")
      if hashes and text then
        lines[i] = hashes .. " " .. title_case(text)
      end
    end
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  end,
})
