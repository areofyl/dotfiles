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
        "harper_ls",
      },
    },
  },

  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
    },
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      -- System clangd (not managed by mason)
      vim.lsp.config("clangd", {
        capabilities = capabilities,
      })
      vim.lsp.enable("clangd")

      -- grammar checking
      vim.lsp.config("harper_ls", {
        capabilities = capabilities,
        filetypes = { "markdown", "text", "gitcommit" },
        settings = {
          ["harper-ls"] = {
            linters = {
              spell_check = true,
              spelled_numbers = false,
              an_a = true,
              sentence_capitalization = false,
              unclosed_quotes = true,
              wrong_quotes = false,
              long_sentences = false,
              repeated_words = true,
              spaces = true,
              matcher = true,
              correct_number_suffix = true,
              number_suffix_capitalization = true,
              multiple_sequential_pronouns = true,
            },
          },
        },
      })
      vim.lsp.enable("harper_ls")

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

      -- Format on save using LSP
      vim.api.nvim_create_autocmd("BufWritePre", {
        callback = function(args)
          local clients = vim.lsp.get_clients({ bufnr = args.buf, method = "textDocument/formatting" })
          if #clients > 0 then
            vim.lsp.buf.format({ bufnr = args.buf, timeout_ms = 3000 })
          end
        end,
      })
    end,
  },
}
