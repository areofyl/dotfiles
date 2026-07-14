return {
  {
    "OXY2DEV/markview.nvim",
    ft = "markdown",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = {},
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
        end,
      })
    end,
  },
}
