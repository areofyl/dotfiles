local map = vim.keymap.set

-- Save
map("n", "<leader>w", "<cmd>w<cr>", { desc = "Save" })

-- Quit
map("n", "<leader>q", "<cmd>q<cr>", { desc = "Quit" })

-- Window navigation
map("n", "<C-h>", "<C-w>h", { desc = "Go to left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Go to lower window" })
map("n", "<C-k>", "<C-w>k", { desc = "Go to upper window" })
map("n", "<C-l>", "<C-w>l", { desc = "Go to right window" })

-- Buffer navigation
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Prev buffer" })
map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next buffer" })
map("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Delete buffer" })

-- Move lines
map("n", "<A-j>", "<cmd>m .+1<cr>==", { desc = "Move line down" })
map("n", "<A-k>", "<cmd>m .-2<cr>==", { desc = "Move line up" })
map("v", "<A-j>", ":m '>+1<cr>gv=gv", { desc = "Move selection down" })
map("v", "<A-k>", ":m '<-2<cr>gv=gv", { desc = "Move selection up" })

-- Better indenting
map("v", "<", "<gv")
map("v", ">", ">gv")

-- Clear search highlight
map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear highlights" })

-- Compile and run
map("n", "<leader>r", function()
  local file = vim.fn.expand("%:p")
  local name = vim.fn.expand("%:p:r")
  local ext = vim.fn.expand("%:e")
  local cmd
  if ext == "c" then
    cmd = string.format("gcc %s -o %s && %s", file, name, name)
  elseif ext == "cpp" then
    cmd = string.format("g++ %s -o %s && %s", file, name, name)
  elseif ext == "py" then
    cmd = string.format("python3 %s", file)
  else
    vim.notify("No run command for ." .. ext, vim.log.levels.WARN)
    return
  end
  vim.cmd("w")
  vim.cmd("split | terminal " .. cmd)
end, { desc = "Compile & run" })

-- Diagnostics
map("n", "[d", vim.diagnostic.goto_prev, { desc = "Prev diagnostic" })
map("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
map("n", "<leader>e", vim.diagnostic.open_float, { desc = "Line diagnostics" })
