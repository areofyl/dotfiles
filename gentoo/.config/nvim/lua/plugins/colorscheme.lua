return {
  -- Use custom nimbus colorscheme (in colors/nimbus.lua)
  -- No plugin needed, just set it on startup
  {
    "nvim-lualine/lualine.nvim",
    optional = true,
    opts = function(_, opts)
      -- lualine auto-detects from vim.g.colors_name
      opts.options = opts.options or {}
      opts.options.theme = "auto"
    end,
  },
  {
    dir = ".",
    name = "nimbus",
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("nimbus")
    end,
  },
}
