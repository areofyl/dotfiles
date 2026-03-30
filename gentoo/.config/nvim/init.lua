-- init.lua

-- ============================================================
-- General settings
-- ============================================================
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.cursorline = true
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.wrap = false
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.clipboard = "unnamedplus"
vim.opt.updatetime = 250
vim.opt.termguicolors = true
vim.opt.signcolumn = "yes"
vim.opt.backup = false
vim.opt.swapfile = false
vim.opt.undofile = true

-- ============================================================
-- Bootstrap lazy.nvim
-- ============================================================
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup("plugins", {
  change_detection = { notify = false },
})

-- ============================================================
-- Keymaps
-- ============================================================
local map = vim.keymap.set

-- Window navigation
map("n", "<C-h>", "<C-w>h")
map("n", "<C-j>", "<C-w>j")
map("n", "<C-k>", "<C-w>k")
map("n", "<C-l>", "<C-w>l")

-- Buffer navigation
map("n", "H", "<cmd>bprevious<cr>")
map("n", "L", "<cmd>bnext<cr>")
map("n", "<leader>bd", "<cmd>bdelete<cr>")

-- Save and quit
map("n", "<leader>w", "<cmd>w<cr>")
map("n", "<leader>q", "<cmd>q<cr>")

-- Move lines
map("n", "<A-j>", "<cmd>m .+1<cr>==")
map("n", "<A-k>", "<cmd>m .-2<cr>==")
map("v", "<A-j>", ":m '>+1<cr>gv=gv")
map("v", "<A-k>", ":m '<-2<cr>gv=gv")

-- Stay in visual mode when indenting
map("v", "<", "<gv")
map("v", ">", ">gv")

-- Clear search highlight
map("n", "<esc>", "<cmd>noh<cr>")

-- Terminal toggle
map("n", "<leader>tt", function()
  local buf = vim.fn.bufnr("term://")
  if buf ~= -1 and vim.fn.bufwinid(buf) ~= -1 then
    vim.api.nvim_win_close(vim.fn.bufwinid(buf), true)
  else
    vim.cmd("botright split | resize " .. math.floor(vim.o.lines / 3))
    if buf ~= -1 then
      vim.cmd("buffer " .. buf)
    else
      vim.cmd("terminal")
    end
    vim.cmd("startinsert")
  end
end)
map("t", "<esc><esc>", "<C-\\><C-n>")

-- ============================================================
-- :Run and :Stop commands
-- ============================================================
local function run_file()
  vim.cmd("w")
  local file = vim.fn.expand("%:p")
  local ext = vim.fn.expand("%:e")
  local base = vim.fn.expand("%:p:r")
  local cmd

  if ext == "c" then
    cmd = string.format("gcc %s -o %s && %s", file, base, base)
  elseif ext == "cpp" then
    cmd = string.format("g++ %s -o %s && %s", file, base, base)
  elseif ext == "py" then
    cmd = string.format("python3 %s", file)
  elseif ext == "go" then
    cmd = string.format("go run %s", file)
  else
    vim.notify("No run command for ." .. ext, vim.log.levels.ERROR)
    return
  end

  -- Close existing run window
  local buf = vim.fn.bufnr("*run*")
  if buf ~= -1 then
    local win = vim.fn.bufwinid(buf)
    if win ~= -1 then vim.api.nvim_win_close(win, true) end
    vim.api.nvim_buf_delete(buf, { force = true })
  end

  vim.cmd("botright split | resize " .. math.floor(vim.o.lines / 3))
  vim.fn.termopen(cmd)
  vim.api.nvim_buf_set_name(0, "*run*")
  vim.cmd("startinsert")
end

local function stop_run()
  local buf = vim.fn.bufnr("*run*")
  if buf ~= -1 then
    local win = vim.fn.bufwinid(buf)
    if win ~= -1 then vim.api.nvim_win_close(win, true) end
    vim.api.nvim_buf_delete(buf, { force = true })
  end
end

vim.api.nvim_create_user_command("Run", run_file, {})
vim.api.nvim_create_user_command("Stop", stop_run, {})
map("n", "<leader>r", run_file)
