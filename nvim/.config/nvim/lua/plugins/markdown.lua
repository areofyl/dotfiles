return {
  {
    "OXY2DEV/markview.nvim",
    ft = "markdown",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = {
      markdown = {
        indented_code_blocks = { enable = false },
        code_blocks = { enable = false },
        inline_codes = { enable = false },
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
      local autolist_group = vim.api.nvim_create_augroup("AutolistMarkdown", { clear = true })
      vim.api.nvim_create_autocmd("FileType", {
        group = autolist_group,
        pattern = "markdown",
        callback = function(args)
          local buf = args.buf
          local map = vim.keymap.set
          map("i", "<CR>", "<CR><cmd>AutolistNewBullet<CR>", { buffer = buf })
          map("n", "o", "o<cmd>AutolistNewBullet<CR>", { buffer = buf })
          map("n", "O", "O<cmd>AutolistNewBulletBefore<CR>", { buffer = buf })
          vim.api.nvim_create_autocmd("TextChangedI", {
            group = autolist_group,
            buffer = buf,
            callback = function()
              local line = vim.api.nvim_get_current_line()
              if line == "* " or line == "- " then
                local row = vim.api.nvim_win_get_cursor(0)[1]
                local new = "    " .. line
                vim.api.nvim_set_current_line(new)
                vim.api.nvim_win_set_cursor(0, { row, #new })
              end
            end,
          })
        end,
      })
    end,
  },
}
