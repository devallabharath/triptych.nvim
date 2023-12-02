local float = require 'tryptic.float'
local help = require 'tryptic.help'
local actions = require 'tryptic.actions'
local view = require 'tryptic.view'
local plenary_path = require 'plenary.path'

-- TODO: The refresh { nil } assertions don't work!
-- Maybe assert a counter instead?

local noop = function() end

describe('help', function()
  it('makes the expected calls', function()
    local spies = {
      float = {
        win_set_title = {},
        win_set_lines = {},
      },
      help = {
        help_lines = {},
      },
    }

    local mock_state = {
      windows = {
        child = {
          win = 3,
        },
      },
    }

    float.win_set_title = function(winid, title, prefix, highlight)
      table.insert(spies.float.win_set_title, { winid, title, prefix, highlight })
    end

    float.win_set_lines = function(winid, lines)
      table.insert(spies.float.win_set_lines, { winid, lines })
    end

    help.help_lines = function()
      table.insert(spies.help.help_lines, nil)
      return { 'hello', 'world' }
    end

    ---@diagnostic disable-next-line: missing-fields
    actions.new(mock_state, {}, {}, noop).help()

    assert.same({ {
      3,
      'Help',
      '󰋗',
      'Directory',
    } }, spies.float.win_set_title)

    assert.same({ nil }, spies.help.help_lines)

    assert.same({ { 3, { 'hello', 'world' } } }, spies.float.win_set_lines)
  end)
end)

describe('delete', function()
  it('makes the expected calls', function()
    local spies = {
      fn = {
        delete = {},
      },
      ui = {
        select = {},
      },
      view = {
        get_target_under_cursor = {},
      },
      refresh = {},
    }

    local mock_state = {}

    local mock_refresh = function()
      table.insert(spies.refresh, nil)
    end

    _G.tryptic_mock_vim = {
      ui = {
        select = function(options, prompt, callback)
          table.insert(spies.ui.select, { options, prompt })
          callback 'Yes'
        end,
      },
      fn = {
        delete = function(path, flags)
          table.insert(spies.fn.delete, { path, flags })
        end,
      },
    }

    view.get_target_under_cursor = function(state)
      table.insert(spies.view.get_target_under_cursor, state)
      return {
        display_name = 'foo',
        path = 'hello/world/foo',
      }
    end

    ---@diagnostic disable-next-line: missing-fields
    actions.new(mock_state, {}, {}, mock_refresh).delete()

    assert.same({ mock_state }, spies.view.get_target_under_cursor)
    assert.same({ { { 'Yes', 'No' }, { prompt = 'Are you sure you want to delete "foo"?' } } }, spies.ui.select)
    assert.same({ { 'hello/world/foo', 'rf' } }, spies.fn.delete)
    assert.same({ nil }, spies.refresh)
  end)

  it('does not delete if confirmation not received', function()
    local spies = {
      fn = {
        delete = {},
      },
      refresh = {},
    }

    local mock_state = {}

    local mock_refresh = function()
      table.insert(spies.refresh, nil)
    end

    _G.tryptic_mock_vim = {
      ui = {
        select = function(_, _, callback)
          callback('No')
        end,
      },
      fn = {
        delete = function(path, flags)
          table.insert(spies.fn.delete, { path, flags })
        end,
      },
    }

    view.get_target_under_cursor = function(_)
      return {
        display_name = 'foo',
        path = 'hello/world/foo',
      }
    end

    ---@diagnostic disable-next-line: missing-fields
    actions.new(mock_state, {}, {}, mock_refresh).delete()

    assert.same({}, spies.refresh)
    assert.same({}, spies.fn.delete)
  end)
end)

describe('bulk_delete', function()
  it('makes the expected calls', function()
    local spies = {
      ui = {
        select = {},
      },
      fn = {
        delete = {},
      },
      refresh = {},
    }

    local mock_state = {}
    local mock_targets = {
      {
        path = 'foo/bar/a.js',
      },
      {
        path = 'foo/bar/b.js',
      },
    }
    local mock_refresh = function()
      table.insert(spies.refresh, nil)
    end

    _G.tryptic_mock_vim = {
      ui = {
        select = function(options, config, callback)
          table.insert(spies.ui.select, { options, config })
          callback 'Yes'
        end,
      },
      fn = {
        delete = function(path, flags)
          table.insert(spies.fn.delete, { path, flags })
        end,
        confirm = function(str, choices, _type)
          table.insert(spies.fn.confirm, { str, choices, _type })
          return 1
        end,
      },
      print = vim.print,
    }

    ---@diagnostic disable-next-line: missing-fields
    actions.new(mock_state, {}, {}, mock_refresh).bulk_delete(mock_targets, false)
    assert.same({ { { 'Yes', 'No' }, { prompt = 'Are you sure you want to delete these 2 items?' } } }, spies.ui.select)
    assert.same({
      { 'foo/bar/a.js', 'rf' },
      { 'foo/bar/b.js', 'rf' },
    }, spies.fn.delete)
    assert.same({ nil }, spies.refresh)
  end)

  it('does not present confirmation prompt when flag is true', function()
    local spies = {
      ui = {
        select = 0
      },
      fn = {
        delete = {},
      },
      refresh = {},
    }

    local mock_state = {}
    local mock_targets = {
      {
        path = 'foo/bar/a.js',
      },
      {
        path = 'foo/bar/b.js',
      },
    }
    local mock_refresh = function()
      table.insert(spies.refresh, nil)
    end

    _G.tryptic_mock_vim = {
      ui = {
        select = function (_, _, _)
          spies.ui.select = spies.ui.select + 1
        end
      },
      fn = {
        delete = function(path, flags)
          table.insert(spies.fn.delete, { path, flags })
        end,
      },
      print = vim.print,
    }

    ---@diagnostic disable-next-line: missing-fields
    actions.new(mock_state, {}, {}, mock_refresh).bulk_delete(mock_targets, true)
    assert.same(0, spies.ui.select)
    assert.same({
      { 'foo/bar/a.js', 'rf' },
      { 'foo/bar/b.js', 'rf' },
    }, spies.fn.delete)
    assert.same({ nil }, spies.refresh)
  end)

  it('does not delete if confirmation not received', function()
    local spies = {
      ui = {
        select = {}
      },
      fn = {
        delete = {},
      },
      refresh = {},
    }

    local mock_state = {}
    local mock_targets = {
      {
        path = 'foo/bar/a.js',
      },
      {
        path = 'foo/bar/b.js',
      },
    }
    local mock_refresh = function()
      table.insert(spies.refresh, nil)
    end

    _G.tryptic_mock_vim = {
      ui = {
        select = function (_, _, callback)
          callback('No')
        end
      },
      fn = {
        delete = function(path, flags)
          table.insert(spies.fn.delete, { path, flags })
        end,
      },
      print = vim.print,
    }

    ---@diagnostic disable-next-line: missing-fields
    actions.new(mock_state, {}, {}, mock_refresh).bulk_delete(mock_targets, false)

    assert.same({}, spies.fn.delete)
    assert.same({}, spies.refresh)
  end)
end)

describe('add_file_or_dir', function()
  it('creates a file', function()
    local spies = {
      fn = {
        trim = {},
        writefile = {},
        mkdir = {},
        input = {},
      },
      refresh = {},
    }

    local mock_state = {
      windows = {
        current = {
          path = '/foo/bar',
        },
      },
    }

    local mock_refresh = function()
      table.insert(spies.refresh, nil)
    end

    _G.tryptic_mock_vim = {
      fn = {
        input = function(prompt)
          table.insert(spies.fn.input, prompt)
          return 'hello.lua'
        end,
        trim = function(str)
          table.insert(spies.fn.trim, str)
          return str
        end,
        writefile = function(lines, path)
          table.insert(spies.fn.writefile, { lines, path })
        end,
        mkdir = function(path, flags)
          table.insert(spies.fn.mkdir, { path, flags })
        end,
      },
    }

    ---@diagnostic disable-next-line: missing-fields
    actions.new(mock_state, {}, {}, mock_refresh).add_file_or_dir()

    assert.same({ 'hello.lua' }, spies.fn.trim)
    assert.same({ 'Enter name for new file or directory (dirs end with a "/"): ' }, spies.fn.input)
    assert.same({ { {}, '/foo/bar/hello.lua' } }, spies.fn.writefile)
    assert.same({ nil }, spies.refresh)
  end)

  it('creates a dir', function()
    local spies = {
      fn = {
        trim = {},
        writefile = {},
        mkdir = {},
        input = {},
      },
      refresh = {},
    }

    local mock_state = {
      windows = {
        current = {
          path = '/foo/bar',
        },
      },
    }

    local mock_refresh = noop

    _G.tryptic_mock_vim = {
      fn = {
        input = function(_)
          return 'new_dir/'
        end,
        trim = function(str)
          return str
        end,
        writefile = function(_, _) end,
        mkdir = function(path, flags)
          table.insert(spies.fn.mkdir, { path, flags })
        end,
      },
    }

    ---@diagnostic disable-next-line: missing-fields
    actions.new(mock_state, {}, {}, mock_refresh).add_file_or_dir()

    assert.same({ { '/foo/bar/new_dir/', 'p' } }, spies.fn.mkdir)
  end)

  it('handles nested dirs', function()
    local spies = {
      fn = {
        trim = {},
        writefile = {},
        mkdir = {},
        input = {},
      },
      refresh = {},
    }

    local mock_state = {
      windows = {
        current = {
          path = '/foo/bar',
        },
      },
    }

    local mock_refresh = noop

    _G.tryptic_mock_vim = {
      fn = {
        input = function(_)
          return 'new_dir_1/new_dir_2/new_file.ts'
        end,
        trim = function(str)
          return str
        end,
        writefile = function(lines, path)
          table.insert(spies.fn.writefile, { lines, path })
        end,
        mkdir = function(path, flags)
          table.insert(spies.fn.mkdir, { path, flags })
        end,
      },
    }

    ---@diagnostic disable-next-line: missing-fields
    actions.new(mock_state, {}, {}, mock_refresh).add_file_or_dir()

    assert.same({ { '/foo/bar/new_dir_1/new_dir_2/', 'p' } }, spies.fn.mkdir)
    assert.same({ { {}, '/foo/bar/new_dir_1/new_dir_2/new_file.ts' } }, spies.fn.writefile)
  end)
end)

describe('toggle_cut', function()
  it('makes the expected calls', function()
    local spies = {
      get_target_under_cursor = {},
      list_remove = {},
      list_toggle = {},
      refresh = {},
    }

    local config = require('tryptic.config').create_merged_config {}
    local state_instance = require('tryptic.state').new(config, 2)

    state_instance.list_remove = function(_, list_type, item)
      table.insert(spies.list_remove, { list_type, item })
    end

    state_instance.list_toggle = function(_, list_type, item)
      table.insert(spies.list_toggle, { list_type, item })
    end

    view.get_target_under_cursor = function(_state)
      table.insert(spies.get_target_under_cursor, _state)
      return 'hello'
    end

    local mock_refresh = function()
      table.insert(spies.refresh, nil)
    end

    ---@diagnostic disable-next-line: missing-fields
    actions.new(state_instance, {}, {}, mock_refresh).toggle_cut()

    assert.same({ state_instance }, spies.get_target_under_cursor)
    assert.same({ { 'copy', 'hello' } }, spies.list_remove)
    assert.same({ { 'cut', 'hello' } }, spies.list_toggle)
    assert.same({ nil }, spies.refresh)
  end)
end)

describe('toggle_copy', function()
  it('makes the expected calls', function()
    local spies = {
      get_target_under_cursor = {},
      list_remove = {},
      list_toggle = {},
      refresh = {},
    }

    local config = require('tryptic.config').create_merged_config {}
    local state_instance = require('tryptic.state').new(config, 2)

    state_instance.list_remove = function(_, list_type, item)
      table.insert(spies.list_remove, { list_type, item })
    end

    state_instance.list_toggle = function(_, list_type, item)
      table.insert(spies.list_toggle, { list_type, item })
    end

    view.get_target_under_cursor = function(_state)
      table.insert(spies.get_target_under_cursor, _state)
      return 'hello'
    end

    local mock_refresh = function()
      table.insert(spies.refresh, nil)
    end

    ---@diagnostic disable-next-line: missing-fields
    actions.new(state_instance, {}, {}, mock_refresh).toggle_copy()

    assert.same({ state_instance }, spies.get_target_under_cursor)
    assert.same({ { 'cut', 'hello' } }, spies.list_remove)
    assert.same({ { 'copy', 'hello' } }, spies.list_toggle)
    assert.same({ nil }, spies.refresh)
  end)
end)

describe('bulk_toggle_cut', function()
  it('Adds items to the cut list', function()
    local spies = {
      view = {
        get_targets_in_selection = {},
      },
      state = {
        list_contains = {},
        list_add = {},
        list_remove = {},
      },
      refresh = {},
    }

    local mock_paths = {
      'hello',
      'world',
      'wow',
    }

    local config = require('tryptic.config').create_merged_config {}
    local state_instance = require('tryptic.state').new(config, 2)

    state_instance.list_contains = function(_, list_type, item)
      table.insert(spies.state.list_contains, { list_type, item })
      if item == mock_paths[1] or item == mock_paths[2] then
        return true
      end
      return false
    end

    state_instance.list_remove = function(_, list_type, item)
      table.insert(spies.state.list_remove, { list_type, item })
    end

    state_instance.list_add = function(_, list_type, item)
      table.insert(spies.state.list_add, { list_type, item })
    end

    view.get_targets_in_selection = function(state)
      table.insert(spies.view.get_targets_in_selection, state)
      return mock_paths
    end

    local mock_refresh = function()
      table.insert(spies.refresh, nil)
    end

    ---@diagnostic disable-next-line: missing-fields
    actions.new(state_instance, {}, {}, mock_refresh).bulk_toggle_cut()

    assert.same({ state_instance }, spies.view.get_targets_in_selection)
    assert.same({
      { 'cut', 'hello' },
      { 'cut', 'world' },
      { 'cut', 'wow' },
    }, spies.state.list_contains)
    -- TODO: does this mean 'hello' and 'world' are being double added?
    assert.same({
      { 'cut', 'hello' },
      { 'cut', 'world' },
      { 'cut', 'wow' },
    }, spies.state.list_add)
    assert.same({ nil }, spies.refresh)
  end)

  it('remove items from the cut list', function()
    local spies = {
      state = {
        list_remove = {},
      },
    }

    local mock_paths = {
      'hello',
      'world',
      'wow',
    }

    local config = require('tryptic.config').create_merged_config {}
    local state_instance = require('tryptic.state').new(config, 2)

    state_instance.list_contains = function(_, _, _)
      return true
    end

    state_instance.list_remove = function(_, list_type, item)
      table.insert(spies.state.list_remove, { list_type, item })
    end

    state_instance.list_add = function(_, _, _) end

    view.get_targets_in_selection = function(_)
      return mock_paths
    end

    ---@diagnostic disable-next-line: missing-fields
    actions.new(state_instance, {}, {}, noop).bulk_toggle_cut()

    assert.same({
      { 'cut', 'hello' },
      { 'cut', 'world' },
      { 'cut', 'wow' },
    }, spies.state.list_remove)
  end)
end)

describe('bulk_toggle_copy', function()
  it('Adds items to the copy list', function()
    local spies = {
      view = {
        get_targets_in_selection = {},
      },
      state = {
        list_contains = {},
        list_add = {},
        list_remove = {},
      },
      refresh = {},
    }

    local mock_paths = {
      'hello',
      'world',
      'wow',
    }

    local config = require('tryptic.config').create_merged_config {}
    local state_instance = require('tryptic.state').new(config, 2)

    state_instance.list_contains = function(_, list_type, item)
      table.insert(spies.state.list_contains, { list_type, item })
      if item == mock_paths[1] or item == mock_paths[2] then
        return true
      end
      return false
    end

    state_instance.list_remove = function(_, list_type, item)
      table.insert(spies.state.list_remove, { list_type, item })
    end

    state_instance.list_add = function(_, list_type, item)
      table.insert(spies.state.list_add, { list_type, item })
    end

    view.get_targets_in_selection = function(state)
      table.insert(spies.view.get_targets_in_selection, state)
      return mock_paths
    end

    local mock_refresh = function()
      table.insert(spies.refresh, nil)
    end

    ---@diagnostic disable-next-line: missing-fields
    actions.new(state_instance, {}, {}, mock_refresh).bulk_toggle_copy()

    assert.same({ state_instance }, spies.view.get_targets_in_selection)
    assert.same({
      { 'copy', 'hello' },
      { 'copy', 'world' },
      { 'copy', 'wow' },
    }, spies.state.list_contains)
    -- TODO: does this mean 'hello' and 'world' are being double added?
    assert.same({
      { 'copy', 'hello' },
      { 'copy', 'world' },
      { 'copy', 'wow' },
    }, spies.state.list_add)
    assert.same({ nil }, spies.refresh)
  end)

  it('remove items from the copy list', function()
    local spies = {
      state = {
        list_remove = {},
      },
    }

    local mock_paths = {
      'hello',
      'world',
      'wow',
    }

    local config = require('tryptic.config').create_merged_config {}
    local state_instance = require('tryptic.state').new(config, 2)

    state_instance.list_contains = function(_, _, _)
      return true
    end

    state_instance.list_remove = function(_, list_type, item)
      table.insert(spies.state.list_remove, { list_type, item })
    end

    state_instance.list_add = function(_, _, _) end

    view.get_targets_in_selection = function(_)
      return mock_paths
    end

    ---@diagnostic disable-next-line: missing-fields
    actions.new(state_instance, {}, {}, noop).bulk_toggle_copy()

    assert.same({
      { 'copy', 'hello' },
      { 'copy', 'world' },
      { 'copy', 'wow' },
    }, spies.state.list_remove)
  end)
end)

describe('rename', function()
  it('renames the target', function()
    local spies = {
      fn = {
        trim = {},
        input = {},
        rename = {},
      },
      view = {
        get_target_under_cursor = {},
      },
      refresh = 0,
    }

    _G.tryptic_mock_vim = {
      fn = {
        trim = function(str)
          table.insert(spies.fn.trim, str)
          return str
        end,
        input = function(str)
          table.insert(spies.fn.input, str)
          return 'bar.js'
        end,
        rename = function(from, to)
          table.insert(spies.fn.rename, { from, to })
        end,
      },
    }

    local mock_state = {}

    view.get_target_under_cursor = function(state)
      table.insert(spies.view.get_target_under_cursor, state)
      return {
        is_dir = false,
        display_name = 'foo.js',
        path = '/hello/world/foo.js',
        dirname = '/hello/world',
      }
    end

    local mock_refresh = function()
      spies.refresh = spies.refresh + 1
    end

    ---@diagnostic disable-next-line: missing-fields
    actions.new(mock_state, {}, {}, mock_refresh).rename()

    assert.same({ mock_state }, spies.view.get_target_under_cursor)
    assert.same({ 'bar.js' }, spies.fn.trim)
    assert.same({ 'Enter new name for "foo.js": ' }, spies.fn.input)
    assert.same({ { '/hello/world/foo.js', '/hello/world/bar.js' } }, spies.fn.rename)
  end)
end)

describe('paste', function()
  it('pastes the items in the copy list', function()
    _G.tryptic_mock_vim = {
      print = vim.print,
    }

    local spies = {
      view = {
        get_target_under_cursor = {},
        jump_cursor_to = {},
      },
      plenary_path = {
        new = {},
        copy = {},
      },
      actions = {
        bulk_delete = {},
      },
      state = {
        list_remove_all = {},
      },
      refresh = 0,
    }

    local config = require('tryptic.config').create_merged_config {}
    local state_instance = require('tryptic.state').new(config, 2)

    state_instance.list_remove_all = function(_, list_type)
      table.insert(spies.state.list_remove_all, list_type)
    end

    state_instance.cut_list = {
      ---@diagnostic disable-next-line: missing-fields
      {
        basename = 'foo.js',
        path = '/hello/world/foo.js',
      },
      ---@diagnostic disable-next-line: missing-fields
      {
        basename = 'bar.js',
        path = '/hello/world/bar.js',
      },
    }

    view.get_target_under_cursor = function(state)
      table.insert(spies.view.get_target_under_cursor, state)
      return {
        is_dir = true,
        path = '/hello/world/wow',
        dirname = '/hello/world/wow',
      }
    end

    view.jump_cursor_to = function(state, dest)
      table.insert(spies.view.jump_cursor_to, { state, dest })
    end

    plenary_path.new = function(_, path)
      table.insert(spies.plenary_path.new, path)
      return {
        copy = function(_, opts)
          table.insert(spies.plenary_path.copy, opts)
        end,
      }
    end

    local mock_refresh = function()
      spies.refresh = spies.refresh + 1
    end

    ---@diagnostic disable-next-line: missing-fields
    local actions_instance = actions.new(state_instance, {}, {}, mock_refresh)

    actions_instance.bulk_delete = function(list, skip_confirm)
      table.insert(spies.actions.bulk_delete, { list, skip_confirm })
    end

    actions_instance.paste()

    assert.same({ state_instance }, spies.view.get_target_under_cursor)
    assert.same({ '/hello/world/foo.js', '/hello/world/bar.js' }, spies.plenary_path.new)
    assert.same({
      {
        destination = '/hello/world/wow/foo.js',
        recursive = true,
        override = false,
        interactive = true,
      },
      {
        destination = '/hello/world/wow/bar.js',
        recursive = true,
        override = false,
        interactive = true,
      },
    }, spies.plenary_path.copy)
    assert.same({
      {
        {
          state_instance.cut_list[1],
          state_instance.cut_list[2],
        },
        true,
      },
    }, spies.actions.bulk_delete)
    assert.same({ { state_instance, '/hello/world/wow' } }, spies.view.jump_cursor_to)
    assert.same({ 'cut', 'copy' }, spies.state.list_remove_all)
    assert.same(1, spies.refresh)
  end)

  it('pastes the items in the cut list', function()
    _G.tryptic_mock_vim = {
      print = vim.print,
    }

    local spies = {
      view = {
        get_target_under_cursor = {},
        jump_cursor_to = {},
      },
      plenary_path = {
        new = {},
        copy = {},
      },
      state = {
        list_remove_all = {},
      },
      refresh = 0,
    }

    local config = require('tryptic.config').create_merged_config {}
    local state_instance = require('tryptic.state').new(config, 2)

    state_instance.list_remove_all = function(_, list_type)
      table.insert(spies.state.list_remove_all, list_type)
    end

    state_instance.copy_list = {
      ---@diagnostic disable-next-line: missing-fields
      {
        basename = 'foo.js',
        path = '/hello/world/foo.js',
      },
      ---@diagnostic disable-next-line: missing-fields
      {
        basename = 'bar.js',
        path = '/hello/world/bar.js',
      },
    }

    view.get_target_under_cursor = function(state)
      table.insert(spies.view.get_target_under_cursor, state)
      return {
        is_dir = true,
        path = '/hello/world/wow',
        dirname = '/hello/world/wow',
      }
    end

    view.jump_cursor_to = function(state, dest)
      table.insert(spies.view.jump_cursor_to, { state, dest })
    end

    plenary_path.new = function(_, path)
      table.insert(spies.plenary_path.new, path)
      return {
        copy = function(_, opts)
          table.insert(spies.plenary_path.copy, opts)
        end,
      }
    end

    local mock_refresh = function()
      spies.refresh = spies.refresh + 1
    end

    ---@diagnostic disable-next-line: missing-fields
    local actions_instance = actions.new(state_instance, {}, {}, mock_refresh)

    actions_instance.paste()

    assert.same({ state_instance }, spies.view.get_target_under_cursor)
    assert.same({ '/hello/world/foo.js', '/hello/world/bar.js' }, spies.plenary_path.new)
    assert.same({
      {
        destination = '/hello/world/wow/foo.js',
        recursive = true,
        override = false,
        interactive = true,
      },
      {
        destination = '/hello/world/wow/bar.js',
        recursive = true,
        override = false,
        interactive = true,
      },
    }, spies.plenary_path.copy)
    assert.same({ { state_instance, '/hello/world/wow' } }, spies.view.jump_cursor_to)
    assert.same({ 'cut', 'copy' }, spies.state.list_remove_all)
    assert.same(2, spies.refresh) -- TODO: Look into duplicate refresh calls
  end)
end)

describe('edit_file', function()
  it('closes tryptic and opens the file', function()
    local spies = {
      close = 0,
      cmd = {
        edit = {},
      },
    }

    _G.tryptic_mock_vim = {
      g = {
        tryptic_close = function()
          spies.close = spies.close + 1
        end,
      },
      cmd = {
        edit = function(path)
          table.insert(spies.cmd.edit, path)
        end,
      },
    }

    ---@diagnostic disable-next-line: missing-fields
    actions.new({}, {}, {}, noop).edit_file '/hello/foo.js'

    assert.same({ '/hello/foo.js' }, spies.cmd.edit)
    assert.same(1, spies.close)
  end)
end)

describe('toggle_hidden', function()
  it('closes tryptic and opens the file', function()
    local spies = {
      refresh = 0,
    }

    local function mock_refresh()
      spies.refresh = spies.refresh + 1
    end

    local mock_state = {
      show_hidden = false,
    }

    ---@diagnostic disable-next-line: missing-fields
    local actions_instance = actions.new(mock_state, {}, {}, mock_refresh)
    actions_instance.toggle_hidden()
    assert.same(true, mock_state.show_hidden)
    actions_instance.toggle_hidden()
    assert.same(false, mock_state.show_hidden)
    assert.same(2, spies.refresh)
  end)
end)

describe('jump_to_cwd', function()
  it('jumps to root if we not already there', function()
    local spies = {
      fn = {
        getcwd = 0,
      },
      view = {
        nav_to = {},
      },
    }
    _G.tryptic_mock_vim = {
      fn = {
        getcwd = function()
          spies.fn.getcwd = spies.fn.getcwd + 1
          return '/hello'
        end,
      },
    }
    view.nav_to = function(s, dir, d, g)
      table.insert(spies.view.nav_to, { s, dir, d, g })
    end
    local mock_state = {
      windows = {
        current = {
          path = '/hello/world/foo',
          previous_path = '/hello',
        },
      },
    }
    local mock_git = { 'git' }
    local mock_diagnostics = { 'diagnostic' }
    local actions_instance = actions.new(mock_state, mock_diagnostics, mock_git, noop)
    actions_instance.jump_to_cwd()
    assert.same(1, spies.fn.getcwd)
    assert.same({
      { mock_state, '/hello', mock_diagnostics, mock_git },
    }, spies.view.nav_to)
  end)

  it('if currently in root, jumps to previous path', function()
    local spies = {
      fn = {
        getcwd = 0,
      },
      view = {
        nav_to = {},
      },
    }
    _G.tryptic_mock_vim = {
      fn = {
        getcwd = function()
          spies.fn.getcwd = spies.fn.getcwd + 1
          return '/hello'
        end,
      },
    }
    view.nav_to = function(s, dir, d, g)
      table.insert(spies.view.nav_to, { s, dir, d, g })
    end
    local mock_state = {
      windows = {
        current = {
          path = '/hello',
          previous_path = '/hello/world/foo',
        },
      },
    }
    local mock_git = { 'git' }
    local mock_diagnostics = { 'diagnostic' }
    local actions_instance = actions.new(mock_state, mock_diagnostics, mock_git, noop)
    actions_instance.jump_to_cwd()
    assert.same(1, spies.fn.getcwd)
    assert.same({
      { mock_state, '/hello/world/foo', mock_diagnostics, mock_git },
    }, spies.view.nav_to)
  end)
end)
