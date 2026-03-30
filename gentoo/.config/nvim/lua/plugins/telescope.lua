return {
  {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find files" },
      { "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Live grep" },
      { "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Buffers" },
      { "<leader>fh", "<cmd>Telescope help_tags<cr>", desc = "Help" },
      { "<leader>pf", "<cmd>Telescope find_files<cr>", desc = "Project files" },
      { "<leader>pg", "<cmd>Telescope live_grep<cr>", desc = "Project grep" },
      { "<leader>pb", "<cmd>Telescope buffers<cr>", desc = "Project buffers" },
    },
    config = function()
      require("telescope").setup({
        defaults = {
          layout_strategy = "vertical",
          layout_config = {
            height = 0.8,
          },
        },
      })
    end,
  },
}
