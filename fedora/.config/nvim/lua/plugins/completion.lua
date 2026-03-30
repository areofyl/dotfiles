return {
  {
    "saghen/blink.cmp",
    version = "1.*",
    event = "InsertEnter",
    opts = {
      keymap = { preset = "default" },
      completion = {
        keyword = { range = "full" },
        list = {
          selection = { preselect = true, auto_insert = false },
        },
        menu = { auto_show = true },
      },
      sources = {
        default = { "lsp", "snippets", "path", "buffer" },
      },
    },
  },
}
