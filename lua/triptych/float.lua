local u = require 'triptych.utils'
local fs = require 'triptych.fs'
local syntax_highlighting = require 'triptych.syntax_highlighting'

local M = {}

---Modify a buffer which is readonly and not modifiable
---@param buf number
---@param fn fun(): nil
---@return nil
local function modify_locked_buffer(buf, fn)
  local vim = _G.triptych_mock_vim or vim
  vim.api.nvim_buf_set_option(buf, 'readonly', false)
  vim.api.nvim_buf_set_option(buf, 'modifiable', true)
  fn()
  vim.api.nvim_buf_set_option(buf, 'readonly', true)
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
end

---@param buf number
---@param lines string[]
---@return nil
function M.buf_set_lines(buf, lines)
  local vim = _G.triptych_mock_vim or vim
  modify_locked_buffer(buf, function()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  end)
end

--- Add highlights for icons and file/directory names. Not to be confused with the syntax highlighting for preview buffers
---@param buf number
---@param highlights HighlightDetails[]
---@return nil
function M.buf_apply_highlights(buf, highlights)
  local vim = _G.triptych_mock_vim or vim
  -- Apply icon highlight
  for i, highlight in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(buf, 0, highlight.icon.highlight_name, i - 1, 0, highlight.icon.length)
    -- Apply file or directory highlight
    vim.api.nvim_buf_add_highlight(buf, 0, highlight.text.highlight_name, i - 1, highlight.text.starts, -1)
  end
end

--- Read the contents of a file into the window buffer
---@param win number
---@param lines string[]
---@param attempt_scroll_top? boolean
function M.win_set_lines(win, lines, attempt_scroll_top)
  local vim = _G.triptych_mock_vim or vim
  local buf = vim.api.nvim_win_get_buf(win)
  M.buf_set_lines(buf, lines)
  if attempt_scroll_top then
    vim.api.nvim_buf_call(buf, function()
      vim.api.nvim_exec2('normal! zb', {})
    end)
  end
end

---@param win number
---@param title string
---@param icon? string
---@param highlight? string
---@param postfix? string
---@return nil
function M.win_set_title(win, title, icon, highlight, postfix)
  local vim = _G.triptych_mock_vim or vim
  vim.api.nvim_win_call(win, function()
    local maybe_icon = ''
    if vim.g.triptych_config.options.file_icons.enabled and icon then
      if highlight then
        maybe_icon = u.with_highlight_group("TriptychTitle", icon) .. ' '
      else
        maybe_icon = icon .. ' '
      end
    end
    local safe_title = string.gsub(title, '%%', '')
    if postfix and postfix ~= '' then
      safe_title = safe_title .. ' ' .. u.with_highlight_group('TriptychTitleAlt', postfix)
    end
    local title_with_hi = u.with_highlight_group('TriptychTitle', safe_title)
    vim.wo.winbar = u.with_highlight_group('TriptychTitle', '%=' .. maybe_icon .. title_with_hi .. '%=')
  end)
end

---@param buf number
---@param path string
---@param lines string[]
function M.set_child_window_file_preview(buf, path, lines)
  local ft = fs.get_filetype_from_path(path)
  syntax_highlighting.stop(buf)
  M.buf_set_lines(buf, lines)
  if vim.g.triptych_config.options.syntax_highlighting.enabled then
    syntax_highlighting.start(buf, ft)
  end
end

---@return number
local function create_new_buffer()
  local vim = _G.triptych_mock_vim or vim
  local buf = vim.api.nvim_create_buf(false, true)
  return buf
end

---@param config FloatingWindowConfig
---@return number
local function create_floating_window(config)
  local vim = _G.triptych_mock_vim or vim
  local buf = create_new_buffer()
  local win = vim.api.nvim_open_win(buf, true, {
    width = config.width,
    height = config.height,
    relative = 'editor',
    col = config.x_pos,
    row = config.y_pos,
    border = config.border,
    style = 'minimal',
    noautocmd = true,
    focusable = config.is_focusable,
    zindex = 101,
  })
  local curr_hl = vim.api.nvim_get_hl_by_name('Cursor', true)
  curr_hl.blend = 100
  vim.opt.guicursor:append('a:Cursor/lCursor')
  vim.api.nvim_set_hl(0, 'Cursor', curr_hl)
  vim.api.nvim_win_set_var(win, 'triptych_role', config.role)
  vim.api.nvim_win_set_option(win, 'winhl', 'Normal:TriptychNormal,FloatBorder:TriptychBorder')
  vim.api.nvim_win_set_option(win, 'cursorline', config.enable_cursorline)
  vim.api.nvim_win_set_option(win, 'number', config.show_numbers)
  vim.api.nvim_win_set_option(win, 'relativenumber', config.relative_numbers)
  if config.show_numbers then
    -- 2 to accomodate both diagnostics and git signs
    vim.api.nvim_win_set_option(win, 'signcolumn', 'auto:2')
  end
  return win
end

---@param winblend number
---@return number
local function create_backdrop(winblend)
  local vim = _G.triptych_mock_vim or vim
  local buf = create_new_buffer()
  local win = vim.api.nvim_open_win(buf, false, {
    width = vim.o.columns,
    height = vim.o.lines,
    relative = 'editor',
    col = 0,
    row = 0,
    style = 'minimal',
    noautocmd = true,
    focusable = false,
    zindex = 100,
  })
  vim.api.nvim_set_hl(0, 'TriptychBackdrop', { bg = '#000000', default = true })
  -- vim.api.nvim_win_set_option(win, 'winhighlight', 'Normal:TriptychBackdrop')
  vim.api.nvim_win_set_option(win, 'winblend', winblend)
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'filetype', 'triptych_backdrop')
  return win
end

---@param show_numbers boolean
---@param relative_numbers boolean
---@param column_widths number[]
---@param backdrop number
---@return number[] 4 window ids (parent, primary, child, backdrop)
function M.create_three_floating_windows(border, show_numbers, relative_numbers, max_w, max_h, column_widths, backdrop)
  local vim = _G.triptych_mock_vim or vim
  local screen_height = vim.o.lines
  local screen_width = vim.o.columns
  local padding = 4

  local float_widths = u.map(column_widths, function(percentage)
    local max = math.floor(max_w * percentage)
    local result = math.min(math.floor((screen_width * percentage)) - padding, max)
    return result
  end)

  local float_height = math.min(screen_height - (padding * 2), max_h)

  local wins = {}

  local x_pos = u.cond(screen_width > (max_w + padding), {
    when_true = math.floor((screen_width - max_w) / 2),
    when_false = padding,
  })

  local y_pos = u.cond(screen_height > (max_h + (padding * 2)), {
    when_true = math.floor((screen_height - max_h) / 2),
    when_false = padding,
  })

  local primary_win = create_floating_window {
    width = float_widths[1],
    height = float_height,
    border = border,
    y_pos = y_pos,
    x_pos = x_pos,
    omit_left_border = false,
    omit_right_border = false,
    enable_cursorline = true,
    is_focusable = false,
    show_numbers = show_numbers,
    relative_numbers = relative_numbers,
    role = 'primary',
  }

  table.insert(wins, primary_win)

  local child_win = create_floating_window {
    width = float_widths[2],
    height = float_height,
    y_pos = y_pos,
    x_pos = x_pos + float_widths[1],
    omit_left_border = false,
    omit_right_border = false,
    enable_cursorline = true,
    is_focusable = true,
    show_numbers = show_numbers,
    relative_numbers = relative_numbers,
    role = 'child',
  }

  table.insert(wins,child_win)
  -- Focus the first window
  vim.api.nvim_set_current_win(wins[1])

  if backdrop < 100 and vim.o.termguicolors then
    local backdrop_win = create_backdrop(backdrop)
    table.insert(wins, backdrop_win)
  end

  return wins
end

---@param wins number[]
---@return nil
function M.close_floats(wins)
  local vim = _G.triptych_mock_vim or vim
  for _, win in ipairs(wins) do
    local buf = vim.api.nvim_win_get_buf(win)
    vim.api.nvim_buf_delete(buf, { force = true })
    -- In some circumstances the window can remain after the buffer is deleted
    -- But we need to wrap this in pcall to suppress errors when this isn't the case
    pcall(vim.api.nvim_win_close, win, { force = true })
  end
  local hl = vim.api.nvim_get_hl_by_name('Cursor', true)
  hl.blend = 0
  vim.api.nvim_set_hl(0, 'Cursor', hl)
  vim.opt.guicursor:remove('a:Cursor/lCursor')
end

return M
