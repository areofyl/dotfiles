return {
  "catgoose/nvim-colorizer.lua",
  event = { "BufReadPost", "BufNewFile" },
  opts = {
    filetypes = { "*" },
    user_default_options = {
      names = false,
      css = true,
      mode = "background",
    },
  },
}
