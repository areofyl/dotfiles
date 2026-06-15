-- Theme colorscheme — reads ~/.config/theme/palette.sh directly

vim.cmd("hi clear")
if vim.fn.exists("syntax_on") then vim.cmd("syntax reset") end
vim.o.termguicolors = true
vim.g.colors_name = "nimbus"

local function load_palette()
  local p = {}
  for line in io.lines(vim.fn.expand("~/.config/theme/palette.sh")) do
    local k, v = line:match("^(%w+)='(#%x+)'")
    if k then p[k] = v end
  end
  return p
end

local p = load_palette()
local c = {
  bg      = p.bg,
  bg1     = p.bg1,
  bg2     = p.bg2,
  bg3     = p.bg3,
  bg4     = p.bg4,
  fg      = p.fg,
  fg1     = p.fg1,
  dim     = p.dim,
  sage    = p.green,
  lavender = p.lavender,
  accent  = p.accent,
  red     = p.red,
  yellow  = p.yellow,
  cyan    = p.cyan,
  magenta = p.magenta,
  green   = p.green2,
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
hi("CursorLineNr", { fg = c.accent, bold = true })
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
hi("Search",       { fg = c.bg, bg = c.lavender })
hi("IncSearch",    { fg = c.bg, bg = c.lavender })
hi("CurSearch",    { fg = c.bg, bg = c.lavender, bold = true })
hi("Substitute",   { fg = c.bg, bg = c.red })

-- Pmenu (completion)
hi("Pmenu",        { fg = c.fg1, bg = c.bg2 })
hi("PmenuSel",     { fg = c.fg, bg = c.bg3, bold = true })
hi("PmenuSbar",    { bg = c.bg2 })
hi("PmenuThumb",   { bg = c.bg4 })

-- Messages
hi("ErrorMsg",     { fg = c.red, bold = true })
hi("WarningMsg",   { fg = c.accent, bold = true })
hi("MoreMsg",      { fg = c.sage })
hi("Question",     { fg = c.sage })
hi("ModeMsg",      { fg = c.fg, bold = true })

-- Folds & special
hi("Folded",       { fg = c.dim, bg = c.bg1 })
hi("FoldColumn",   { fg = c.bg4, bg = c.bg })
hi("NonText",      { fg = c.bg3 })
hi("SpecialKey",   { fg = c.bg3 })
hi("Conceal",      { fg = c.dim })
hi("MatchParen",   { fg = c.accent, bold = true, underline = true })
hi("Directory",    { fg = c.sage })
hi("Title",        { fg = c.accent, bold = true })

-- Diff
hi("DiffAdd",      { bg = p.diff_add })
hi("DiffChange",   { bg = p.diff_change })
hi("DiffDelete",   { fg = c.red, bg = p.diff_delete })
hi("DiffText",     { bg = p.diff_text, bold = true })

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
hi("Function",     { fg = c.accent })
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
hi("Special",      { fg = c.accent })
hi("SpecialChar",  { fg = c.accent })
hi("Tag",          { fg = c.accent })
hi("Delimiter",    { fg = c.fg1 })
hi("Debug",        { fg = c.accent })
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
hi("@function",           { fg = c.accent })
hi("@function.builtin",   { fg = c.accent })
hi("@function.call",      { fg = c.accent })
hi("@function.macro",     { fg = c.cyan })
hi("@method",             { fg = c.accent })
hi("@method.call",        { fg = c.accent })
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
hi("@tag",                { fg = c.accent })
hi("@tag.attribute",      { fg = c.yellow })
hi("@tag.delimiter",      { fg = c.fg1 })
hi("@attribute",          { fg = c.yellow })
hi("@property",           { fg = c.fg1 })
hi("@field",              { fg = c.fg1 })

-- LSP
hi("DiagnosticError",          { fg = c.red })
hi("DiagnosticWarn",           { fg = c.accent })
hi("DiagnosticInfo",           { fg = c.lavender })
hi("DiagnosticHint",           { fg = c.sage })
hi("DiagnosticUnderlineError", { undercurl = true, sp = c.red })
hi("DiagnosticUnderlineWarn",  { undercurl = true, sp = c.accent })
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
hi("TelescopePromptTitle",  { fg = c.bg, bg = c.accent, bold = true })
hi("TelescopeResultsTitle", { fg = c.dim })
hi("TelescopePreviewTitle", { fg = c.bg, bg = c.sage, bold = true })
hi("TelescopeSelection",    { bg = c.bg3, bold = true })
hi("TelescopeMatching",     { fg = c.accent, bold = true })

-- Git signs
hi("GitSignsAdd",    { fg = c.sage })
hi("GitSignsChange", { fg = c.lavender })
hi("GitSignsDelete", { fg = c.red })

-- Indent blankline
hi("IblIndent", { fg = c.bg2 })
hi("IblScope",  { fg = c.bg4 })

-- Which-key
hi("WhichKey",          { fg = c.accent })
hi("WhichKeyGroup",     { fg = c.lavender })
hi("WhichKeyDesc",      { fg = c.fg1 })
hi("WhichKeySeparator", { fg = c.dim })

-- Alpha dashboard
hi("NimbusHeader",  { fg = c.lavender })
hi("NimbusFooter",  { fg = c.dim })
