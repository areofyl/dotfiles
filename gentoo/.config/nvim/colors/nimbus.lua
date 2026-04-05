-- Nimbus colorscheme
-- Matches the system palette: bg #1a1510, fg #d4c4b0, sage, lavender, orange, dim

vim.cmd("hi clear")
if vim.fn.exists("syntax_on") then vim.cmd("syntax reset") end
vim.o.termguicolors = true
vim.g.colors_name = "nimbus"

local c = {
  bg      = "#1a1510",
  bg1     = "#221c15",
  bg2     = "#2c2519",
  bg3     = "#3a3128",
  bg4     = "#4a3f34",
  fg      = "#d4c4b0",
  fg1     = "#c0b09c",
  dim     = "#7a6e62",
  sage    = "#a0b89a",
  lavender = "#9a9ab8",
  orange  = "#c08060",
  red     = "#c07070",
  yellow  = "#c8b070",
  cyan    = "#80a8a0",
  magenta = "#b080a8",
  green   = "#88a878",
  none    = "NONE",
}

local function hi(group, opts)
  vim.api.nvim_set_hl(0, group, opts)
end

-- Editor
hi("Normal",       { fg = c.fg, bg = c.bg })
hi("NormalFloat",  { fg = c.fg, bg = c.bg1 })
hi("FloatBorder",  { fg = c.dim, bg = c.bg1 })
hi("Cursor",       { fg = c.bg, bg = c.fg })
hi("CursorLine",   { bg = c.bg1 })
hi("CursorColumn", { bg = c.bg1 })
hi("ColorColumn",  { bg = c.bg1 })
hi("LineNr",       { fg = c.bg4 })
hi("CursorLineNr", { fg = c.orange, bold = true })
hi("SignColumn",   { bg = c.bg })
hi("VertSplit",    { fg = c.bg3 })
hi("WinSeparator", { fg = c.bg3 })
hi("StatusLine",   { fg = c.fg1, bg = c.bg2 })
hi("StatusLineNC", { fg = c.dim, bg = c.bg1 })
hi("TabLine",      { fg = c.dim, bg = c.bg1 })
hi("TabLineSel",   { fg = c.fg, bg = c.bg2, bold = true })
hi("TabLineFill",  { bg = c.bg1 })
hi("WinBar",       { fg = c.fg1, bg = c.bg })
hi("WinBarNC",     { fg = c.dim, bg = c.bg })

-- Search & visual
hi("Visual",       { bg = c.bg3 })
hi("VisualNOS",    { bg = c.bg3 })
hi("Search",       { fg = c.bg, bg = c.yellow })
hi("IncSearch",    { fg = c.bg, bg = c.orange })
hi("CurSearch",    { fg = c.bg, bg = c.orange, bold = true })
hi("Substitute",   { fg = c.bg, bg = c.red })

-- Pmenu (completion)
hi("Pmenu",        { fg = c.fg1, bg = c.bg2 })
hi("PmenuSel",     { fg = c.fg, bg = c.bg3, bold = true })
hi("PmenuSbar",    { bg = c.bg2 })
hi("PmenuThumb",   { bg = c.bg4 })

-- Messages
hi("ErrorMsg",     { fg = c.red, bold = true })
hi("WarningMsg",   { fg = c.orange, bold = true })
hi("MoreMsg",      { fg = c.sage })
hi("Question",     { fg = c.sage })
hi("ModeMsg",      { fg = c.fg, bold = true })

-- Folds & special
hi("Folded",       { fg = c.dim, bg = c.bg1 })
hi("FoldColumn",   { fg = c.bg4, bg = c.bg })
hi("NonText",      { fg = c.bg3 })
hi("SpecialKey",   { fg = c.bg3 })
hi("Conceal",      { fg = c.dim })
hi("MatchParen",   { fg = c.orange, bold = true, underline = true })
hi("Directory",    { fg = c.sage })
hi("Title",        { fg = c.orange, bold = true })

-- Diff
hi("DiffAdd",      { bg = "#1e2a1a" })
hi("DiffChange",   { bg = "#1e1e2a" })
hi("DiffDelete",   { fg = c.red, bg = "#2a1a1a" })
hi("DiffText",     { bg = "#2a2a1e", bold = true })

-- Spelling
hi("SpellBad",     { undercurl = true, sp = c.red })
hi("SpellCap",     { undercurl = true, sp = c.lavender })
hi("SpellRare",    { undercurl = true, sp = c.magenta })
hi("SpellLocal",   { undercurl = true, sp = c.cyan })

-- Syntax
hi("Comment",      { fg = c.dim, italic = true })
hi("Constant",     { fg = c.lavender })
hi("String",       { fg = c.sage })
hi("Character",    { fg = c.sage })
hi("Number",       { fg = c.lavender })
hi("Boolean",      { fg = c.lavender })
hi("Float",        { fg = c.lavender })
hi("Identifier",   { fg = c.fg })
hi("Function",     { fg = c.orange })
hi("Statement",    { fg = c.red })
hi("Conditional",  { fg = c.red })
hi("Repeat",       { fg = c.red })
hi("Label",        { fg = c.red })
hi("Operator",     { fg = c.fg1 })
hi("Keyword",      { fg = c.red })
hi("Exception",    { fg = c.red })
hi("PreProc",      { fg = c.cyan })
hi("Include",      { fg = c.cyan })
hi("Define",       { fg = c.cyan })
hi("Macro",        { fg = c.cyan })
hi("PreCondit",    { fg = c.cyan })
hi("Type",         { fg = c.yellow })
hi("StorageClass", { fg = c.yellow })
hi("Structure",    { fg = c.yellow })
hi("Typedef",      { fg = c.yellow })
hi("Special",      { fg = c.orange })
hi("SpecialChar",  { fg = c.orange })
hi("Tag",          { fg = c.orange })
hi("Delimiter",    { fg = c.fg1 })
hi("Debug",        { fg = c.orange })
hi("Underlined",   { fg = c.lavender, underline = true })
hi("Error",        { fg = c.red, bold = true })
hi("Todo",         { fg = c.yellow, bg = c.bg2, bold = true })

-- Treesitter
hi("@variable",           { fg = c.fg })
hi("@variable.builtin",   { fg = c.magenta })
hi("@variable.parameter", { fg = c.fg1 })
hi("@constant",           { fg = c.lavender })
hi("@constant.builtin",   { fg = c.lavender })
hi("@module",             { fg = c.fg1 })
hi("@string",             { fg = c.sage })
hi("@string.escape",      { fg = c.cyan })
hi("@string.regex",       { fg = c.cyan })
hi("@character",          { fg = c.sage })
hi("@number",             { fg = c.lavender })
hi("@boolean",            { fg = c.lavender })
hi("@float",              { fg = c.lavender })
hi("@function",           { fg = c.orange })
hi("@function.builtin",   { fg = c.orange })
hi("@function.call",      { fg = c.orange })
hi("@function.macro",     { fg = c.cyan })
hi("@method",             { fg = c.orange })
hi("@method.call",        { fg = c.orange })
hi("@constructor",        { fg = c.yellow })
hi("@keyword",            { fg = c.red })
hi("@keyword.function",   { fg = c.red })
hi("@keyword.return",     { fg = c.red })
hi("@keyword.operator",   { fg = c.red })
hi("@conditional",        { fg = c.red })
hi("@repeat",             { fg = c.red })
hi("@exception",          { fg = c.red })
hi("@include",            { fg = c.cyan })
hi("@type",               { fg = c.yellow })
hi("@type.builtin",       { fg = c.yellow })
hi("@type.qualifier",     { fg = c.red })
hi("@operator",           { fg = c.fg1 })
hi("@punctuation.bracket",    { fg = c.fg1 })
hi("@punctuation.delimiter",  { fg = c.fg1 })
hi("@punctuation.special",    { fg = c.cyan })
hi("@comment",            { fg = c.dim, italic = true })
hi("@tag",                { fg = c.orange })
hi("@tag.attribute",      { fg = c.yellow })
hi("@tag.delimiter",      { fg = c.fg1 })
hi("@attribute",          { fg = c.yellow })
hi("@property",           { fg = c.fg1 })
hi("@field",              { fg = c.fg1 })

-- LSP
hi("DiagnosticError",          { fg = c.red })
hi("DiagnosticWarn",           { fg = c.orange })
hi("DiagnosticInfo",           { fg = c.lavender })
hi("DiagnosticHint",           { fg = c.sage })
hi("DiagnosticUnderlineError", { undercurl = true, sp = c.red })
hi("DiagnosticUnderlineWarn",  { undercurl = true, sp = c.orange })
hi("DiagnosticUnderlineInfo",  { undercurl = true, sp = c.lavender })
hi("DiagnosticUnderlineHint",  { undercurl = true, sp = c.sage })
hi("LspReferenceText",        { bg = c.bg2 })
hi("LspReferenceRead",        { bg = c.bg2 })
hi("LspReferenceWrite",       { bg = c.bg2 })

-- Telescope
hi("TelescopeNormal",       { fg = c.fg, bg = c.bg1 })
hi("TelescopeBorder",       { fg = c.dim, bg = c.bg1 })
hi("TelescopePromptNormal", { fg = c.fg, bg = c.bg2 })
hi("TelescopePromptBorder", { fg = c.dim, bg = c.bg2 })
hi("TelescopePromptTitle",  { fg = c.bg, bg = c.orange, bold = true })
hi("TelescopeResultsTitle", { fg = c.dim })
hi("TelescopePreviewTitle", { fg = c.bg, bg = c.sage, bold = true })
hi("TelescopeSelection",    { bg = c.bg3, bold = true })
hi("TelescopeMatching",     { fg = c.orange, bold = true })

-- Git signs
hi("GitSignsAdd",    { fg = c.sage })
hi("GitSignsChange", { fg = c.lavender })
hi("GitSignsDelete", { fg = c.red })

-- Indent blankline
hi("IblIndent", { fg = c.bg2 })
hi("IblScope",  { fg = c.bg4 })

-- Which-key
hi("WhichKey",          { fg = c.orange })
hi("WhichKeyGroup",     { fg = c.lavender })
hi("WhichKeyDesc",      { fg = c.fg1 })
hi("WhichKeySeparator", { fg = c.dim })

-- Alpha dashboard
hi("NimbusHeader",  { fg = c.orange })
hi("NimbusFooter",  { fg = c.dim })

-- Lualine will pick up Normal/StatusLine automatically
