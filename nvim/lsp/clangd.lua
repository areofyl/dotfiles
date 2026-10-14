return {
  cmd = {
    "clangd",
    "--background-index",
    "--clang-tidy",
    "--completion-style=detailed",
    "--header-insertion=iwyu",
    "--function-arg-placeholders",
    "--all-scopes-completion",
    "--pch-storage=memory",
    "--fallback-style=none",
  },
  filetypes = { "c", "cpp", "objc", "objcpp" },
}
