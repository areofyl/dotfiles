local capabilities = require("cmp_nvim_lsp").default_capabilities()
vim.lsp.config("*", { capabilities = capabilities })
vim.lsp.enable({ "clangd", "pylsp", "ruff", "harper_ls" })

vim.diagnostic.config({
  virtual_text = { spacing = 4, prefix = "●" },
  severity_sort = true,
  signs = true,
  underline = true,
  float = { border = "rounded", source = true },
})

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local buf = args.buf
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client then return end

    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = desc })
    end

    -- navigation
    map("n", "gd", vim.lsp.buf.definition, "Go to definition")
    map("n", "gD", vim.lsp.buf.declaration, "Go to declaration")
    map("n", "gr", vim.lsp.buf.references, "References")
    map("n", "gi", vim.lsp.buf.implementation, "Go to implementation")
    map("n", "gy", vim.lsp.buf.type_definition, "Type definition")

    -- info
    map("n", "K", vim.lsp.buf.hover, "Hover")
    map("n", "<C-k>", vim.lsp.buf.signature_help, "Signature help")
    map("i", "<C-k>", vim.lsp.buf.signature_help, "Signature help")

    -- signature help fed into eldoc echo (replaces floating window)
    if client:supports_method("textDocument/signatureHelp") then
      vim.api.nvim_create_autocmd("InsertCharPre", {
        buffer = buf,
        callback = function()
          local char = vim.v.char
          if char == "(" or char == "," then
            vim.schedule(function()
              eldoc_signature(buf)
            end)
          end
        end,
      })
    end

    -- actions
    map("n", "<leader>cr", vim.lsp.buf.rename, "Rename")
    map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")

    -- diagnostics
    map("n", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, "Previous diagnostic")
    map("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end, "Next diagnostic")
    map("n", "<leader>cd", vim.diagnostic.open_float, "Line diagnostics")
    map("n", "<leader>cq", vim.diagnostic.setloclist, "Diagnostics to loclist")

    -- inlay hints (on by default, toggle with <leader>ch)
    if client:supports_method("textDocument/inlayHint") then
      vim.lsp.inlay_hint.enable(true, { bufnr = buf })
      map("n", "<leader>ch", function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = buf }), { bufnr = buf })
      end, "Toggle inlay hints")
    end

    -- code lens
    if client:supports_method("textDocument/codeLens") then
      vim.lsp.codelens.enable(true, { bufnr = buf })
      map("n", "<leader>cl", vim.lsp.codelens.run, "Run code lens")
    end

  end,
})

-- eldoc: show hover + signature help in statusline

-- stored eldoc statusline string (with highlight codes baked in)
vim.g.eldoc_stl = ""

local function stl_escape(s)
  return s:gsub("%%", "%%%%")
end

local function eldoc_set(parts)
  -- parts = list of {text, hlgroup} pairs -> statusline string
  if #parts == 0 then
    vim.g.eldoc_stl = ""
  else
    local s = {}
    for _, p in ipairs(parts) do
      s[#s + 1] = ("%%#%s#%s"):format(p[2], stl_escape(p[1]))
    end
    s[#s + 1] = "%*"
    vim.g.eldoc_stl = table.concat(s)
  end
  vim.cmd.redrawstatus()
end

local function strip_md(text)
  if not text or text == "" then return "" end
  local out = {}
  local in_code = false
  for l in text:gmatch("[^\n]+") do
    if l:match("^```") then
      in_code = not in_code
    elseif not l:match("^%-%-%-$") then
      if in_code then
        l = l:gsub("^%s+", " "):gsub("%s+$", "")
      else
        l = l:gsub("^#+%s*", "")
        l = l:gsub("%*%*(.-)%*%*", "%1")
        l = l:gsub("`(.-)`", "%1")
        l = l:gsub("\\(.)", "%1")
        l = l:gsub("^%s+", ""):gsub("%s+$", "")
      end
      if l ~= "" then out[#out + 1] = l end
    end
  end
  return table.concat(out, " ")
end

-- signature help: parse and show with active param highlighted
function eldoc_signature(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/signatureHelp" })
  if #clients == 0 then return end

  local params = vim.lsp.util.make_position_params(0, clients[1].offset_encoding)
  vim.lsp.buf_request(bufnr, "textDocument/signatureHelp", params, function(err, result)
    if err or not result or not result.signatures or #result.signatures == 0 then return end

    local sig = result.signatures[(result.activeSignature or 0) + 1] or result.signatures[1]
    local label = sig.label
    local active_idx = sig.activeParameter or result.activeParameter or 0
    local parts = {}

    local highlighted = false
    if sig.parameters and sig.parameters[active_idx + 1] then
      local p = sig.parameters[active_idx + 1]
      local ps, pe
      if type(p.label) == "table" then
        ps, pe = p.label[1], p.label[2]
      elseif type(p.label) == "string" then
        ps, pe = label:find(vim.pesc(p.label), 1, true)
        if ps then ps = ps - 1 end
      end
      if ps and pe then
        if ps > 0 then parts[#parts + 1] = { label:sub(1, ps), "Function" } end
        parts[#parts + 1] = { label:sub(ps + 1, pe), "WarningMsg" }
        if pe < #label then parts[#parts + 1] = { label:sub(pe + 1), "Function" } end
        highlighted = true
      end
    end

    if not highlighted then
      parts[#parts + 1] = { label, "Function" }
    end

    if sig.parameters and sig.parameters[active_idx + 1] then
      local pdoc = sig.parameters[active_idx + 1].documentation
      if pdoc then
        local text = type(pdoc) == "string" and pdoc or (pdoc.value or "")
        text = strip_md(text)
        if text ~= "" then
          parts[#parts + 1] = { "  —  ", "NonText" }
          parts[#parts + 1] = { text, "Comment" }
        end
      end
    end

    eldoc_set(parts)
  end)
end

-- C keyword/builtin reference
local c_ref = {
  ["if"] = "if (cond) { ... } — conditional branch",
  ["else"] = "else { ... } — alternative branch, pairs with if",
  ["for"] = "for (init; cond; step) { ... } — loop",
  ["while"] = "while (cond) { ... } — loop while condition is true",
  ["do"] = "do { ... } while (cond); — loop, body runs at least once",
  ["switch"] = "switch (expr) { case val: ... } — multi-way branch",
  ["case"] = "case value: — label inside switch",
  ["default"] = "default: — fallback label inside switch",
  ["return"] = "return expr; — return value from function",
  ["break"] = "break; — exit loop or switch",
  ["continue"] = "continue; — skip to next loop iteration",
  ["goto"] = "goto label; — jump to label",
  ["typedef"] = "typedef type alias; — define type alias",
  ["struct"] = "struct name { fields }; — aggregate type",
  ["union"] = "union name { fields }; — overlapping members",
  ["enum"] = "enum name { A, B, C }; — named integer constants",
  ["sizeof"] = "sizeof(type|expr) — size in bytes",
  ["static"] = "static — internal linkage / persistent local storage",
  ["extern"] = "extern — external linkage, defined elsewhere",
  ["const"] = "const — read-only qualifier",
  ["volatile"] = "volatile — prevent compiler optimization on variable",
  ["inline"] = "inline — hint to inline function body",
  ["register"] = "register — hint to store in CPU register",
  ["void"] = "void — no type / no return value",
  ["int"] = "int — integer type (typically 32-bit)",
  ["char"] = "char — character type (1 byte)",
  ["float"] = "float — single-precision floating-point",
  ["double"] = "double — double-precision floating-point",
  ["long"] = "long — at least 32-bit integer modifier",
  ["short"] = "short — at least 16-bit integer modifier",
  ["signed"] = "signed — signed integer modifier",
  ["unsigned"] = "unsigned — unsigned integer modifier",
  ["auto"] = "auto — automatic storage duration (default)",
  ["_Bool"] = "_Bool — boolean type (C99), 0 or 1",
  ["NULL"] = "NULL — null pointer constant ((void *)0)",
  ["true"] = "true — boolean 1",
  ["false"] = "false — boolean 0",
  ["#include"] = "#include <header> or \"file\" — include header file",
  ["#define"] = "#define NAME value — preprocessor macro",
  ["#ifdef"] = "#ifdef NAME — compile if macro defined",
  ["#ifndef"] = "#ifndef NAME — compile if macro not defined",
  ["#endif"] = "#endif — end preprocessor conditional",
  ["#if"] = "#if expr — compile if expression is true",
  ["#elif"] = "#elif expr — else-if preprocessor branch",
  ["#else"] = "#else — else preprocessor branch",
  ["#pragma"] = "#pragma — compiler-specific directive",
  ["#undef"] = "#undef NAME — undefine macro",
  ["//"] = "// — single-line comment (C99+)",
  ["/*"] = "/* ... */ — multi-line comment",
}

local function get_comment_above(bufnr, row)
  if row <= 0 then return nil end
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, row, false)
  local comments = {}
  for i = #lines, 1, -1 do
    local l = vim.trim(lines[i])
    if l:match("^//") then
      table.insert(comments, 1, l:gsub("^//[!/]?%s?", ""))
    elseif l:match("%*/") then
      for j = i, 1, -1 do
        local bl = vim.trim(lines[j])
        local stripped = bl:gsub("^/%*[%*!]?%s?", ""):gsub("^%*/?%s?", ""):gsub("%s*%*/$", "")
        table.insert(comments, 1, stripped)
        if lines[j]:match("/%*") then break end
      end
      break
    else
      break
    end
  end
  if #comments == 0 then return nil end
  local out = {}
  for _, c in ipairs(comments) do
    c = vim.trim(c)
    if c ~= "" and c ~= "*" then out[#out + 1] = c end
  end
  return #out > 0 and table.concat(out, " ") or nil
end

local function parse_hover_text(text)
  local sig_parts, doc_parts = {}, {}
  local in_code = false
  for l in text:gmatch("[^\n]+") do
    if l:match("^```") then
      in_code = not in_code
    elseif l:match("^%-%-%-$") then
    elseif in_code then
      l = l:gsub("^%s+", " "):gsub("%s+$", "")
      if l ~= "" then sig_parts[#sig_parts + 1] = l end
    else
      l = l:gsub("^#+%s*", ""):gsub("%*%*(.-)%*%*", "%1"):gsub("`(.-)`", "%1"):gsub("\\(.)", "%1")
      l = l:gsub("^%s+", ""):gsub("%s+$", "")
      if l ~= "" then doc_parts[#doc_parts + 1] = l end
    end
  end
  local parts = {}
  if #sig_parts > 0 then
    parts[#parts + 1] = { table.concat(sig_parts, " "), "Function" }
  end
  if #doc_parts > 0 then
    if #parts > 0 then parts[#parts + 1] = { "  —  ", "NonText" } end
    parts[#parts + 1] = { table.concat(doc_parts, " "), "Comment" }
  end
  eldoc_set(parts)
end

local function eldoc_hover()
  local bufnr = vim.api.nvim_get_current_buf()
  local word = vim.fn.expand("<cword>")
  local clients = vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/hover" })

  local function try_fallback()
    if c_ref[word] then
      eldoc_set({ { word, "Function" }, { "  —  ", "NonText" }, { c_ref[word], "Comment" } })
      return
    end
    local line = vim.api.nvim_get_current_line()
    local pp = line:match("^%s*(#%w+)")
    if pp and c_ref[pp] then
      eldoc_set({ { pp, "Function" }, { "  —  ", "NonText" }, { c_ref[pp], "Comment" } })
      return
    end
    local prefix = line:sub(1, vim.fn.col("."))
    if prefix:match("/%*") and c_ref["/*"] then
      eldoc_set({ { "/*", "Function" }, { "  —  ", "NonText" }, { c_ref["/*"], "Comment" } })
      return
    end
    if prefix:match("//") and c_ref["//"] then
      eldoc_set({ { "//", "Function" }, { "  —  ", "NonText" }, { c_ref["//"], "Comment" } })
      return
    end
    local row = vim.api.nvim_win_get_cursor(0)[1] - 1
    local comment = get_comment_above(bufnr, row)
    if comment and word ~= "" then
      eldoc_set({ { word, "Function" }, { "  —  ", "NonText" }, { comment, "Comment" } })
      return
    end
    eldoc_set({})
  end

  if #clients == 0 then
    try_fallback()
    return
  end

  local params = vim.lsp.util.make_position_params(0, clients[1].offset_encoding)
  vim.lsp.buf_request(bufnr, "textDocument/hover", params, function(err, result)
    if err or not result or not result.contents then
      if word == "" then eldoc_set({}); return end
      local row = vim.api.nvim_win_get_cursor(0)[1] - 1
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      for i = 0, #lines - 1 do
        if i ~= row then
          local s = lines[i + 1]:find(word, 1, true)
          if s then
            local p2 = vim.lsp.util.make_position_params(0, clients[1].offset_encoding)
            p2.position = { line = i, character = s - 1 }
            vim.lsp.buf_request(bufnr, "textDocument/hover", p2, function(e2, r2)
              if e2 or not r2 or not r2.contents then try_fallback(); return end
              local t = type(r2.contents) == "string" and r2.contents or r2.contents.value
              if not t or t == "" then try_fallback(); return end
              parse_hover_text(t)
            end)
            return
          end
        end
      end
      try_fallback()
      return
    end
    local text = type(result.contents) == "string" and result.contents or result.contents.value
    if not text or text == "" then try_fallback(); return end
    parse_hover_text(text)
  end)
end

vim.api.nvim_create_autocmd("CursorHoldI", {
  callback = function()
    local buf = vim.api.nvim_get_current_buf()
    local clients = vim.lsp.get_clients({ bufnr = buf, method = "textDocument/signatureHelp" })
    if #clients > 0 then
      local line = vim.api.nvim_get_current_line()
      local col = vim.fn.col(".") - 1
      local depth = 0
      for i = col, 1, -1 do
        local ch = line:sub(i, i)
        if ch == ")" then depth = depth + 1
        elseif ch == "(" then
          if depth == 0 then
            eldoc_signature(buf)
            return
          end
          depth = depth - 1
        end
      end
    end
    eldoc_hover()
  end,
})

vim.api.nvim_create_autocmd("CursorHold", {
  callback = eldoc_hover,
})

-- clear eldoc when cursor moves (will be repopulated on next CursorHold)
vim.api.nvim_create_autocmd("CursorMoved", {
  callback = function()
    if vim.g.eldoc_stl ~= "" then
      vim.g.eldoc_stl = ""
      vim.cmd.redrawstatus()
    end
  end,
})

-- format on save
vim.api.nvim_create_autocmd("BufWritePre", {
  callback = function(args)
    local clients = vim.lsp.get_clients({ bufnr = args.buf, method = "textDocument/formatting" })
    if #clients > 0 then
      vim.lsp.buf.format({ bufnr = args.buf, timeout_ms = 3000 })
    end
  end,
})
