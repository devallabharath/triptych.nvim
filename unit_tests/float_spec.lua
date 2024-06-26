local float = require 'triptych.float'
local fs = require 'triptych.fs'
local config = require 'triptych.config'
local syntax_highlighting = require 'triptych.syntax_highlighting'

describe('create_three_floating_windows', function()
  it('makes the expected nvim api calls', function()
    -- spies
    local nvim_open_win_spy = {}
    local nvim_win_set_option_spy = {}
    local nvim_buf_set_option_spy = {}
    local nvim_win_set_var_spy = {}
    local nvim_create_buf_spy = {}
    local nvim_set_current_win_spy = {}
    local nvim_buf_set_lines_spy = {}
    local nvim_set_hl_spy = {}

    -- incrementing indexes used for window and buffer ids
    local bufid = 0
    local winid = 0

    -- mocks
    _G.triptych_mock_vim = {
      o = {
        lines = 40,
        columns = 60,
        termguicolors = true,
      },
      api = {
        nvim_create_buf = function(listed, scratch)
          table.insert(nvim_create_buf_spy, { listed, scratch })
          bufid = bufid + 1
          return bufid
        end,
        nvim_buf_set_lines = function(bid, from, to, strict, lines)
          table.insert(nvim_buf_set_lines_spy, { bid, from, to, strict, lines })
        end,
        nvim_open_win = function(bif, enter, config)
          table.insert(nvim_open_win_spy, { bif, enter, config })
          winid = winid + 1
          return winid
        end,
        nvim_win_set_option = function(wid, opt, value)
          table.insert(nvim_win_set_option_spy, { wid, opt, value })
        end,
        nvim_buf_set_option = function(bid, opt, value)
          table.insert(nvim_buf_set_option_spy, { bid, opt, value })
        end,
        nvim_win_set_var = function(wid, opt, value)
          table.insert(nvim_win_set_var_spy, { wid, opt, value })
        end,
        nvim_set_current_win = function(wid)
          table.insert(nvim_set_current_win_spy, wid)
        end,
        nvim_set_hl = function(nsid, name, val)
          table.insert(nvim_set_hl_spy, { nsid, name, val })
        end,
      },
    }
    local border = config.options.border
    float.create_three_floating_windows(border, true, false, { 0.25, 0.25, 0.5 }, 60)

    assert.same({
      { false, true },
      { false, true },
      { false, true },
      { false, true },
    }, nvim_create_buf_spy)

    assert.same({
      {
        1,
        true,
        {
          width = 11,
          height = 28,
          relative = 'editor',
          col = 4,
          row = 4,
          border = 'single',
          style = 'minimal',
          noautocmd = true,
          focusable = false,
          zindex = 101,
        },
      },
      {
        2,
        true,
        {
          width = 11,
          height = 28,
          relative = 'editor',
          col = 17,
          row = 4,
          border = 'single',
          style = 'minimal',
          noautocmd = true,
          focusable = true,
          zindex = 101,
        },
      },
      {
        3,
        true,
        {
          width = 26,
          height = 28,
          relative = 'editor',
          col = 30,
          row = 4,
          border = 'single',
          style = 'minimal',
          noautocmd = true,
          focusable = false,
          zindex = 101,
        },
      },
      {
        4,
        false,
        {
          width = 60,
          height = 40,
          relative = 'editor',
          col = 0,
          row = 0,
          style = 'minimal',
          noautocmd = true,
          focusable = false,
          zindex = 100,
        },
      },
    }, nvim_open_win_spy)
    assert.same({
      { 1, 'triptych_role', 'parent' },
      { 2, 'triptych_role', 'primary' },
      { 3, 'triptych_role', 'child' },
    }, nvim_win_set_var_spy)
    assert.same({
      -- first win
      { 1, 'cursorline', true },
      { 1, 'number', false },
      { 1, 'relativenumber', false },
      -- second win
      { 2, 'cursorline', true },
      { 2, 'number', true },
      { 2, 'relativenumber', false },
      { 2, 'signcolumn', 'auto:2' },
      -- third win
      { 3, 'cursorline', false },
      { 3, 'number', false },
      { 3, 'relativenumber', false },
      -- fourth (backdrop) win
      { 4, 'winhighlight', 'Normal:TriptychBackdrop' },
      { 4, 'winblend', 60 },
    }, nvim_win_set_option_spy)
    assert.same({ { 4, 'buftype', 'nofile' }, { 4, 'filetype', 'triptych_backdrop' } }, nvim_buf_set_option_spy)
    assert.same({ { 0, 'TriptychBackdrop', { bg = '#000000', default = true } } }, nvim_set_hl_spy)
    assert.same({ 2 }, nvim_set_current_win_spy)
  end)
end)

describe('close_floats', function()
  it('closes a list of floating windows', function()
    local nvim_win_get_buf_spy = {}
    local nvim_win_close_spy = {}
    local nvim_buf_delete_spy = {}

    local bufindex = 0
    _G.triptych_mock_vim = {
      api = {
        nvim_win_get_buf = function(winid)
          table.insert(nvim_win_get_buf_spy, winid)
          bufindex = bufindex + 1
          return bufindex
        end,
        nvim_win_close = function(winid, conf)
          table.insert(nvim_win_close_spy, { winid, conf })
        end,
        nvim_buf_delete = function(bufid, config)
          table.insert(nvim_buf_delete_spy, { bufid, config })
        end,
      },
    }

    float.close_floats { 3, 4, 5 }

    assert.same({ 3, 4, 5 }, nvim_win_get_buf_spy)
    assert.same({
      { 3, { force = true } },
      { 4, { force = true } },
      { 5, { force = true } },
    }, nvim_win_close_spy)
    assert.same({
      { 1, { force = true } },
      { 2, { force = true } },
      { 3, { force = true } },
    }, nvim_buf_delete_spy)
  end)
end)

describe('buf_set_lines', function()
  it('sets lines for a buffer', function()
    local nvim_buf_set_lines_spy = {}
    local nvim_buf_set_option_spy = {}

    _G.triptych_mock_vim = {
      api = {
        nvim_buf_set_lines = function(bufid, from, to, strict, lines)
          table.insert(nvim_buf_set_lines_spy, { bufid, from, to, strict, lines })
        end,
        nvim_buf_set_option = function(bufid, opt, value)
          table.insert(nvim_buf_set_option_spy, { bufid, opt, value })
        end,
      },
    }

    float.buf_set_lines(3, { 'hello', 'world', 'wow' })

    assert.same({
      {
        3,
        0,
        -1,
        false,
        { 'hello', 'world', 'wow' },
      },
    }, nvim_buf_set_lines_spy)

    assert.same({
      { 3, 'readonly', false },
      { 3, 'modifiable', true },
      { 3, 'readonly', true },
      { 3, 'modifiable', false },
    }, nvim_buf_set_option_spy)
  end)
end)

describe('win_set_lines', function()
  it('sets lines for a buffer by window id', function()
    local nvim_buf_set_lines_spy = {}
    local nvim_buf_set_option_spy = {}
    local nvim_win_get_buf_spy = {}

    local mock_buf_id = 12

    _G.triptych_mock_vim = {
      api = {
        nvim_buf_set_lines = function(bufid, from, to, strict, lines)
          table.insert(nvim_buf_set_lines_spy, { bufid, from, to, strict, lines })
        end,
        nvim_buf_set_option = function(bufid, opt, value)
          table.insert(nvim_buf_set_option_spy, { bufid, opt, value })
        end,
        nvim_win_get_buf = function(winid)
          table.insert(nvim_win_get_buf_spy, winid)
          return mock_buf_id
        end,
      },
    }

    float.win_set_lines(3, { 'hello', 'world', 'wow' })

    assert.same({ 3 }, nvim_win_get_buf_spy)

    assert.same({
      {
        mock_buf_id,
        0,
        -1,
        false,
        { 'hello', 'world', 'wow' },
      },
    }, nvim_buf_set_lines_spy)

    assert.same({
      { mock_buf_id, 'readonly', false },
      { mock_buf_id, 'modifiable', true },
      { mock_buf_id, 'readonly', true },
      { mock_buf_id, 'modifiable', false },
    }, nvim_buf_set_option_spy)
  end)

  it('scrolls to top if flag is true', function()
    local nvim_buf_call_spy = {}
    local nvim_exec2_spy = {}

    local mock_buf_id = 12

    _G.triptych_mock_vim = {
      api = {
        nvim_buf_set_lines = function(_, _, _, _, _) end,
        nvim_buf_set_option = function(_, _, _) end,
        nvim_win_get_buf = function(_)
          return mock_buf_id
        end,
        nvim_buf_call = function(bufid, fn)
          table.insert(nvim_buf_call_spy, { bufid, fn })
          fn()
        end,
        nvim_exec2 = function(str, config)
          table.insert(nvim_exec2_spy, { str, config })
        end,
      },
    }

    float.win_set_lines(3, { 'hello', 'world', 'wow' }, true)

    assert.same(mock_buf_id, nvim_buf_call_spy[1][1])
    assert.same({
      { 'normal! zb', {} },
    }, nvim_exec2_spy)
  end)
end)

describe('win_set_title', function()
  it('sets the title for a window', function()
    local spies = {
      nvim_win_call = {},
    }

    _G.triptych_mock_vim = {
      g = {
        triptych_config = require('triptych.config').create_merged_config {},
      },
      wo = {
        winbar = '',
      },
      api = {
        nvim_win_call = function(winid, fn)
          table.insert(spies.nvim_win_call, winid)
          fn()
        end,
      },
    }

    float.win_set_title(6, 'monkey', '+', 'FooHi', '>')

    assert.same({ 6 }, spies.nvim_win_call)
    assert.same('%#WinBar#%=%#FooHi#+ %#WinBar#monkey %#Comment#>%=', _G.triptych_mock_vim.wo.winbar)
  end)
end)

describe('buf_apply_highlights', function()
  it('applies highlights to a buffer', function()
    local nvim_buf_add_highlight_spy = {}
    _G.triptych_mock_vim = {
      api = {
        nvim_buf_add_highlight = function(budid, ns_id, hl_group, line, col_start, col_end)
          table.insert(nvim_buf_add_highlight_spy, { budid, ns_id, hl_group, line, col_start, col_end })
        end,
      },
    }
    float.buf_apply_highlights(4, {
      {
        icon = {
          highlight_name = 'icon_hl',
          length = 5,
        },
        text = {
          highlight_name = 'text_hl',
          starts = 2,
        },
      },
      {
        icon = {
          highlight_name = 'icon_hl_2',
          length = 4,
        },
        text = {
          highlight_name = 'text_hl_2',
          starts = 1,
        },
      },
    })
    assert.same({
      { 4, 0, 'icon_hl', 0, 0, 5 },
      { 4, 0, 'text_hl', 0, 2, -1 },
      { 4, 0, 'icon_hl_2', 1, 0, 4 },
      { 4, 0, 'text_hl_2', 1, 1, -1 },
    }, nvim_buf_add_highlight_spy)
  end)
end)
