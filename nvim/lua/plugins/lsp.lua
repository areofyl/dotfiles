return {
  { "hrsh7th/cmp-nvim-lsp" },

  {
    "mason-org/mason.nvim",
    opts = {},
  },

  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "mason-org/mason.nvim" },
    opts = {
      ensure_installed = {
        "python-lsp-server",
        "clang-format",
        "ruff",
        "harper-ls",
      },
    },
  },
}
