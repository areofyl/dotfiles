return {
  {
    "mason-org/mason.nvim",
    cmd = "Mason",
    opts = {},
  },

  {
    "mason-org/mason-lspconfig.nvim",
    dependencies = {
      "mason-org/mason.nvim",
      "neovim/nvim-lspconfig",
    },
    opts = {
      automatic_enable = true,
    },
  },

  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "mason-org/mason.nvim" },
    opts = {
      ensure_installed = {
        "pylsp",
        "clang-format",
        "ruff",
      },
    },
  },

  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      vim.diagnostic.config({
        virtual_text = { spacing = 4 },
        severity_sort = true,
        signs = true,
        underline = true,
      })

      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local buf = args.buf
          local map = function(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = desc })
          end

          map("n", "gd", vim.lsp.buf.definition, "Go to definition")
          map("n", "gr", vim.lsp.buf.references, "References")
          map("n", "K", vim.lsp.buf.hover, "Hover")
          map("n", "<leader>cr", vim.lsp.buf.rename, "Rename")
          map("n", "<leader>ca", vim.lsp.buf.code_action, "Code action")
          map("n", "gD", vim.lsp.buf.declaration, "Go to declaration")
          map("n", "gi", vim.lsp.buf.implementation, "Go to implementation")
        end,
      })
    end,
  },
}
