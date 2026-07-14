return {
  {
    "OXY2DEV/markview.nvim",
    ft = "markdown",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = {
      markdown = {
        indented_code_blocks = { enable = false },
        list_items = {
          shift_width = 4,
          marker_minus = {
            add_padding = false,
            text = "—",
          },
          marker_star = {
            add_padding = false,
            text = "●",
          },
        },
      },
    },
  },
  {
    "dhruvasagar/vim-table-mode",
    ft = "markdown",
    init = function()
      vim.g.table_mode_corner = "|"
    end,
  },
  {
    "gaoDean/autolist.nvim",
    ft = "markdown",
    opts = {},
    config = function(_, opts)
      require("autolist").setup(opts)
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "markdown",
        callback = function()
          local map = vim.keymap.set
          map("i", "<CR>", "<CR><cmd>AutolistNewBullet<CR>", { buffer = true })
          map("n", "o", "o<cmd>AutolistNewBullet<CR>", { buffer = true })
          map("n", "O", "O<cmd>AutolistNewBulletBefore<CR>", { buffer = true })
          map("i", "<Space>", function()
            local col = vim.fn.col(".") - 1
            local line = vim.api.nvim_get_current_line()
            local before = line:sub(1, col)
            if before == "*" or before == "-" then
              local keys = vim.api.nvim_replace_termcodes("<C-t>", true, false, true)
              vim.api.nvim_feedkeys(keys .. " ", "n", false)
            else
              vim.api.nvim_feedkeys(" ", "n", false)
            end
          end, { buffer = true })
        end,
      })
    end,
  },
}
