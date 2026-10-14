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
}
