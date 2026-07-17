if vim.fn.argc() > 0 then
  return
end

local vim_version = vim.version()

if vim_version.minor < 12 then
  return
end

vim.opt.shortmess:append('I')

local function set_intro_highlights()
  vim.api.nvim_set_hl(0, "IntroTitle", { fg = "#8caaba" })
  vim.api.nvim_set_hl(0, "IntroText", { fg = "#5a6578" })
end

local intro = {
  win = nil,
  buf = nil,
  ns = nil,
  text = nil,
  group = nil
}

intro.ns = vim.api.nvim_create_namespace('IntroOverlayNS')
intro.group = vim.api.nvim_create_augroup('IntroOverlay', { clear = true })

intro.text = {
  { { (' NVIM v%d.%d.%d'):format(vim_version.major, vim_version.minor, vim_version.patch), 'IntroTitle' } },
  { { '' } },
  { { ' Nvim is open source and freely distributable', 'IntroText' } },
  { { ' https://neovim.io/#chat', 'IntroTitle' } },
  { { '' } },
  {
    { 'type :help nvim', 'IntroText' },
    { '<Enter>', 'IntroTitle' },
    { ' if you are new!', 'IntroText' },
  },
  {
    { 'type :checkhealth', 'IntroText' },
    { '<Enter>', 'IntroTitle' },
    { ' to optimize Nvim', 'IntroText' },
  },
  {
    { 'type :q', 'IntroText' },
    { '<Enter>', 'IntroTitle' },
    { ' to exit', 'IntroText' },
  },
  {
    { 'type :help', 'IntroText' },
    { '<Enter>', 'IntroTitle' },
    { ' for help', 'IntroText' },
  },
  { { '' } },
  {
    { 'type :help news', 'IntroText' },
    { '<Enter>', 'IntroTitle' },
    { (' to see changes in v%d.%d'):format(vim_version.major, vim_version.minor), 'IntroText' },
  },
  { { '' } },
  { { ' Help poor children in Uganda!', 'IntroText' } },
  {
    { 'type :help Kuwasha', 'IntroText' },
    { '<Enter>', 'IntroTitle' },
    { ' for information', 'IntroText' },
  },
}

local function create_intro_buf()
  local buf = vim.api.nvim_create_buf(false, true)
  local width = 49

  for i, text in ipairs(intro.text) do
    vim.api.nvim_buf_set_lines(buf, i - 1, i - 1, false, { '' })

    local centered = {}
    local is_type_line = #text == 3 and text[1][1]:match('^type ')

    if is_type_line then
      -- Left-justify command, right-justify description
      local left_len = #text[1][1] + #text[2][1]
      local right = text[3][1]:match('^%s*(.*)')
      local inner = width - 2
      local gap = math.max(1, inner - left_len - #right)
      table.insert(centered, { ' ' })
      table.insert(centered, text[1])
      table.insert(centered, text[2])
      table.insert(centered, { string.rep(' ', gap) .. right, text[3][2] })
    else
      local len = 0
      for _, chunk in ipairs(text) do
        len = len + #chunk[1]
      end
      if len > 0 then
        local pad = math.max(0, math.floor((width - len) / 2))
        table.insert(centered, { string.rep(' ', pad) })
      end
      for _, chunk in ipairs(text) do
        table.insert(centered, chunk)
      end
    end

    vim.api.nvim_buf_set_extmark(buf, intro.ns, i - 1, 0, {
      virt_text = centered,
      virt_text_pos = 'overlay',
    })
  end

  return buf
end

local function create_intro_win(row, col, width, height)
  local win = vim.api.nvim_open_win(intro.buf, false, {
    relative = 'editor',
    row = row,
    col = col,
    width = width,
    height = height,
    style = 'minimal',
    border = 'none',
    focusable = false,
    noautocmd = true,
  })

  vim.wo[win].winhighlight = 'NormalFloat:Normal'

  return win
end

local function hide_intro()
  if intro.win and vim.api.nvim_win_is_valid(intro.win) then
    vim.api.nvim_win_close(intro.win, true)
    intro.win = nil
  end
end

local function render_intro()
  if not intro.buf or not vim.api.nvim_buf_is_valid(intro.buf) then
    intro.buf = create_intro_buf()
  end

  local width = 49
  local height = #intro.text

  local usable_width = vim.o.columns - 1

  if usable_width < width or vim.o.lines < height + 6 then
    hide_intro()
    return
  end

  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((usable_width - width) / 2) + 2

  if not intro.win or not vim.api.nvim_win_is_valid(intro.win) then
    intro.win = create_intro_win(row, col, width, height)
    return
  end

  vim.api.nvim_win_set_config(intro.win, {
    relative = 'editor',
    row = row,
    col = col,
    width = width,
    height = height,
  })
end

local function cleanup_intro()
  hide_intro()

  if intro.group then
    pcall(vim.api.nvim_del_augroup_by_id, intro.group)
    intro.group = nil
  end

  if intro.buf and vim.api.nvim_buf_is_valid(intro.buf) then
    if intro.ns then
      vim.api.nvim_buf_clear_namespace(intro.buf, intro.ns, 0, -1)
      intro.ns = nil
    end

    vim.api.nvim_buf_delete(intro.buf, { force = true })
    intro.buf = nil
  end

  intro.win = nil
  intro.text = nil
end

vim.api.nvim_create_autocmd('VimEnter', {
  once = true,
  callback = function()
    set_intro_highlights()
    render_intro()

    vim.api.nvim_create_autocmd('VimResized', {
      group = intro.group,
      callback = render_intro,
    })

    vim.api.nvim_create_autocmd({
      'InsertCharPre',
      'BufReadPre',
      'CursorMoved',
    }, {
      group = intro.group,
      once = true,
      callback = function()
        vim.schedule(cleanup_intro)
      end,
    })
  end,
})
