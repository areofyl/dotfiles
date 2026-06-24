return {
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = "markdown",
    build = function() vim.fn["mkdp#util#install"]() end,
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
          local al = require("autolist")
          map("i", "<CR>", "<CR><cmd>AutolistNewBullet<CR>", { buffer = true })
          map("n", "o", "o<cmd>AutolistNewBullet<CR>", { buffer = true })
          map("n", "O", "O<cmd>AutolistNewBulletBefore<CR>", { buffer = true })
        end,
      })
    end,
  },
}
