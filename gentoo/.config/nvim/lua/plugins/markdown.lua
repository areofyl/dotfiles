return {
  "MeanderingProgrammer/render-markdown.nvim",
  ft = "markdown",
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
  },
  opts = {
    heading = {
      icons = { "# ", "## ", "### ", "#### ", "##### ", "###### " },
      backgrounds = {
        "RenderMarkdownH1Bg",
        "RenderMarkdownH2Bg",
        "RenderMarkdownH3Bg",
        "RenderMarkdownH4Bg",
        "RenderMarkdownH5Bg",
        "RenderMarkdownH6Bg",
      },
    },
  },
  config = function(_, opts)
    -- define heading bg colors since the vim colorscheme doesn't have them
    vim.api.nvim_set_hl(0, "RenderMarkdownH1Bg", { bg = "#3b2d1a", bold = true })
    vim.api.nvim_set_hl(0, "RenderMarkdownH2Bg", { bg = "#1a2d3b", bold = true })
    vim.api.nvim_set_hl(0, "RenderMarkdownH3Bg", { bg = "#2d1a3b", bold = true })
    vim.api.nvim_set_hl(0, "RenderMarkdownH4Bg", { bg = "#1a3b2d", bold = true })
    vim.api.nvim_set_hl(0, "RenderMarkdownH5Bg", { bg = "#3b1a2d", bold = true })
    vim.api.nvim_set_hl(0, "RenderMarkdownH6Bg", { bg = "#2d3b1a", bold = true })
    require("render-markdown").setup(opts)
  end,
}
