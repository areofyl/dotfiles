local ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
if ok then
  vim.lsp.config("*", { capabilities = cmp_nvim_lsp.default_capabilities() })
end
vim.lsp.enable({ "clangd", "pylsp", "ruff", "harper_ls" })

-- filter out harper sentence length diagnostics
local orig_publish = vim.lsp.handlers["textDocument/publishDiagnostics"]
vim.lsp.handlers["textDocument/publishDiagnostics"] = function(err, result, ctx, config)
  if result and result.diagnostics then
    result.diagnostics = vim.tbl_filter(function(d)
      return not d.message:match("sentence is %d+ words long")
    end, result.diagnostics)
  end
  orig_publish(err, result, ctx, config)
end

vim.diagnostic.config({
  virtual_text = { spacing = 4, prefix = "●" },
  severity_sort = true,
  signs = true,
  underline = true,
  float = { border = "rounded", source = true },
})

local eldoc_signature

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

    -- info
    map("n", "K", vim.lsp.buf.hover, "Hover")
    map("n", "<C-k>", vim.lsp.buf.signature_help, "Signature help")
    map("i", "<C-k>", vim.lsp.buf.signature_help, "Signature help")

    -- signature help fed into statusline (replaces floating window)
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
      -- refresh signature help as you type inside parens
      vim.api.nvim_create_autocmd("TextChangedI", {
        buffer = buf,
        callback = function()
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

-- stored eldoc statusline parts
_G._eldoc_parts = {}

function _G.eldoc_statusline()
  if #_G._eldoc_parts == 0 then return "" end
  local s = {}
  for _, p in ipairs(_G._eldoc_parts) do
    s[#s + 1] = ("%%#%s#%s"):format(p[2], p[1]:gsub("%%", "%%%%"))
  end
  s[#s + 1] = "%*"
  return table.concat(s)
end

local function eldoc_set(parts)
  _G._eldoc_parts = parts
  vim.schedule(function()
    vim.cmd.redrawstatus()
  end)
end

local function split_md(text)
  if not text or text == "" then return "", "" end
  local code, prose = {}, {}
  local in_code = false
  for l in text:gmatch("[^\n]+") do
    if l:match("^```") then
      in_code = not in_code
    elseif not l:match("^%-%-%-$") then
      if in_code then
        l = l:gsub("^%s+", " "):gsub("%s+$", "")
        if l ~= "" then code[#code + 1] = l end
      else
        l = l:gsub("^#+%s*", ""):gsub("%*%*(.-)%*%*", "%1"):gsub("`(.-)`", "%1"):gsub("\\(.)", "%1")
        l = l:gsub("^%s+", ""):gsub("%s+$", "")
        if l ~= "" then prose[#prose + 1] = l end
      end
    end
  end
  return table.concat(code, " "), table.concat(prose, " ")
end

-- signature help: parse and show with active param highlighted
eldoc_signature = function(bufnr)
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
        local raw = type(pdoc) == "string" and pdoc or (pdoc.value or "")
        local _, text = split_md(raw)
        if text ~= "" then
          parts[#parts + 1] = { "  —  ", "NonText" }
          parts[#parts + 1] = { text, "Comment" }
        end
      end
    end

    eldoc_set(parts)
  end)
end -- eldoc_signature

local function parse_hover_text(text)
  local code, prose = split_md(text)
  local parts = {}
  if code ~= "" then
    parts[#parts + 1] = { code, "Function" }
  end
  if prose ~= "" then
    if #parts > 0 then parts[#parts + 1] = { "  —  ", "NonText" } end
    parts[#parts + 1] = { prose, "Comment" }
  end
  eldoc_set(parts)
end

local function eldoc_hover()
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/hover" })

  if #clients == 0 then
    eldoc_set({})
    return
  end

  local params = vim.lsp.util.make_position_params(0, clients[1].offset_encoding)
  vim.lsp.buf_request(bufnr, "textDocument/hover", params, function(err, result)
    if err or not result or not result.contents then
      eldoc_set({})
      return
    end
    local text = type(result.contents) == "string" and result.contents or result.contents.value
    if not text or text == "" then eldoc_set({}); return end
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

-- clear eldoc on cursor move or leaving insert
vim.api.nvim_create_autocmd({ "CursorMoved", "InsertLeave" }, {
  callback = function()
    if #_G._eldoc_parts > 0 then
      eldoc_set({})
    end
  end,
})

-- format on save, then preserve whitespace-only lines
vim.api.nvim_create_autocmd("BufWritePre", {
  callback = function(args)
    local clients = vim.lsp.get_clients({ bufnr = args.buf, method = "textDocument/formatting" })
    if #clients > 0 then
      vim.lsp.buf.format({ bufnr = args.buf, timeout_ms = 3000 })
    end
    local lines = vim.api.nvim_buf_get_lines(args.buf, 0, -1, false)
    local changed = false
    for i, line in ipairs(lines) do
      if line == "" then
        local prev_indent = (lines[i - 1] or ""):match("^([\t ]+)")
        local next_indent = (lines[i + 1] or ""):match("^([\t ]+)")
        local indent = prev_indent or next_indent
        if indent then
          lines[i] = indent
          changed = true
        end
      end
    end
    if changed then
      vim.api.nvim_buf_set_lines(args.buf, 0, -1, false, lines)
    end
  end,
})
