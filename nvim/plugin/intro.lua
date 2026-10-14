if vim.fn.argc() > 0 then return end

vim.opt.shortmess:append("I")

local ns = vim.api.nvim_create_namespace("intro")
local group = vim.api.nvim_create_augroup("Intro", { clear = true })

local saved = {}

local function render()
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  local text = "nvim?"
  local win_h = vim.api.nvim_win_get_height(0)
  local win_w = vim.api.nvim_win_get_width(0)
  local row = math.floor(win_h / 2)
  local col = math.floor((win_w - #text) / 2)

  local lines = {}
  for _ = 1, row do
    table.insert(lines, { { "" } })
  end
  lines[#lines] = { { string.rep(" ", col) .. text, "NonText" } }

  vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, {
    virt_lines = lines,
  })
end

local function hide_ui()
  saved.number = vim.wo.number
  saved.relativenumber = vim.wo.relativenumber
  saved.signcolumn = vim.wo.signcolumn
  saved.cursorline = vim.wo.cursorline
  saved.statusline = vim.o.statusline
  saved.fillchars = vim.o.fillchars

  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.wo.signcolumn = "no"
  vim.wo.cursorline = false
  vim.o.statusline = " "
  vim.o.fillchars = "eob: "
end

local function restore_ui()
  vim.wo.number = saved.number
  vim.wo.relativenumber = saved.relativenumber
  vim.wo.signcolumn = saved.signcolumn
  vim.wo.cursorline = saved.cursorline
  vim.o.statusline = saved.statusline
  vim.o.fillchars = saved.fillchars
end

vim.api.nvim_create_autocmd("VimEnter", {
  group = group,
  once = true,
  callback = function()
    hide_ui()
    render()

    vim.api.nvim_create_autocmd("VimResized", {
      group = group,
      callback = render,
    })

    vim.api.nvim_create_autocmd({ "InsertCharPre", "BufReadPre", "CursorMoved" }, {
      group = group,
      once = true,
      callback = function()
        vim.schedule(function()
          vim.api.nvim_buf_clear_namespace(vim.api.nvim_get_current_buf(), ns, 0, -1)
          restore_ui()
          pcall(vim.api.nvim_del_augroup_by_id, group)
        end)
      end,
    })
  end,
})
