return {
  {
    "echasnovski/mini.pairs",
    event = "InsertEnter",
    opts = {
      modes = { insert = true, command = false, terminal = false },
      mappings = {
        -- disable * pairing so bullets and italic markers work in markdown
        ["*"] = false,
      },
    },
  },
}
