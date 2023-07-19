local map = vim.keymap.set
local t = require 'tryptic'

map('n', 'h', function()
  local parent_path = vim.g.tryptic_state.parent.path
  require 'tryptic'.nav_to(parent_path)
end, { buffer = 0 })

map('n', 'l', function()
  local target = t.get_target_under_cursor()
  if vim.fn.isdirectory(target.path) == 1 then
    require 'tryptic'.nav_to(target.path)
  else
    require 'tryptic'.edit_file(target.path)
  end
end, { buffer = 0 })

map('n', 'd', function()
  require 'tryptic'.delete()
end, { buffer = 0 })

map('n', 'a', function()
  require 'tryptic'.add_file_or_dir()
end, { buffer = 0 })
