local u = require 'triptych.utils'

---@return TriptychConfig
local function default_config()
  return {
    mappings = {
      show_help = 'g?',
      jump_to_cwd = '.',
      nav_left = {'h', '<Left>'},
      nav_right = { 'l', '<CR>', '<Right>' },
      open_hsplit = { 'v' },
      open_vsplit = { 's' },
      open_tab = { 't' },
      cd = '<leader>g',
      delete = 'd',
      add = 'a',
      copy = 'c',
      rename = 'r',
      cut = 'x',
      paste = 'p',
      quit = 'q',
      toggle_hidden = '<leader>.',
    },
    extension_mappings = {},
    options = {
      dirs_first = true,
      show_hidden = false,
      line_numbers = {
        enabled = true,
        relative = false,
      },
      file_icons = {
        enabled = true,
        directory_icon = '',
        fallback_file_icon = '',
      },
      git_signs = {
        enabled = true,
        signs = {
          add = '+',
          modify = '~',
          rename = 'r',
          untracked = '?',
        },
      },
      diagnostic_signs = {
        enabled = true,
      },
      max_width = 200,
      max_height = 30,
      column_widths = { 0.5, 0.5 },
      highlights = {
        file_names = 'NONE',
        directory_names = 'NONE',
      },
      syntax_highlighting = {
        enabled = true,
        debounce_ms = 100,
      },
      backdrop = 100,
      border = { " ", "", "", "▌", "▌", "", "", "▌" },
    },
  }
end

--- Validate column_widths option, and set to default if invalid
---@param user_config table
local validate_column_widths = function(user_config)
  local vim = _G.triptych_mock_vim or vim
  if user_config and user_config.options and user_config.options.column_widths then
    local col_widths = user_config.options.column_widths
    local function set_to_default()
      user_config.options.column_widths = default_config().options.column_widths
    end
    if #col_widths ~= 2 then
      set_to_default()
      vim.notify(
        'triptych config.options.column_widths must be a list of 3 decimal numbers. e.g. { 0.5, 0.5 }',
        vim.log.levels.WARN
      )
    else
      local total = u.round(col_widths[1] + col_widths[2], 2)
      if total ~= 1 then
        set_to_default()
        vim.notify(
          'triptych config.options.column_widths must add up to 1 after rounding to 2 decimal places. e.g. { 0.5, 0.5 }',
          vim.log.levels.WARN
        )
      end
    end
  end
end

---@param user_config table
---@return TriptychConfig
local create_merged_config = function(user_config)
  validate_column_widths(user_config)
  return u.merge_tables(default_config(), user_config)
end

return {
  create_merged_config = create_merged_config,
}
