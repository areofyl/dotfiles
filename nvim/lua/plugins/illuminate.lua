return {
  "echasnovski/mini.cursorword",
  event = { "BufReadPost", "BufNewFile" },
  config = function()
    require("mini.cursorword").setup({ delay = 200 })
    vim.api.nvim_set_hl(0, "MiniCursorword", { underline = true })
    vim.api.nvim_set_hl(0, "MiniCursorwordCurrent", {})
    vim.api.nvim_create_autocmd("ColorScheme", {
      callback = function()
        vim.api.nvim_set_hl(0, "MiniCursorword", { underline = true })
        vim.api.nvim_set_hl(0, "MiniCursorwordCurrent", {})
      end,
    })
  end,
}
