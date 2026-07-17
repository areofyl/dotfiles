return {
  {
    "vague2k/vague.nvim",
    priority = 1000,
    opts = {},
  },
  {
    "rebelot/kanagawa.nvim",
    priority = 1000,
    opts = {},
  },
  {
      "savq/melange-nvim",
      lazy = false,
      priority = 1000,
  },
  {
      "AlexvZyl/nordic.nvim",
      lazy = false,
      priority = 1000,
  },
  {
      "neanias/everforest-nvim",
      lazy = false,
      priority = 1000,
      config = function()
        require("everforest").setup({
          background = "hard",
        })
      end,
  },

}
