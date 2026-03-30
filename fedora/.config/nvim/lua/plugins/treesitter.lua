return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
      ensure_installed = {
        "c",
        "cpp",
        "python",
        "lua",
        "bash",
        "json",
        "yaml",
        "markdown",
        "markdown_inline",
        "vim",
        "vimdoc",
        "query",
      },
      highlight = { enable = true },
      indent = { enable = true },
    },
    main = "nvim-treesitter.config",
  },
}
