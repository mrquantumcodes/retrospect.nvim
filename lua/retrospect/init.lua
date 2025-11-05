-- init.lua: Main entry point for retrospect.nvim
local session = require('retrospect.session')
local ui = require('retrospect.ui')
local M = {}

-- Default configuration
local default_config = {
  save_key = '<leader>\\',
  load_key = '<leader><BS>',
}

local config = {}

-- Save current session
function M.save_session()
  session.save()
end

-- Load a session (shows picker)
function M.load_session()
  ui.show_session_picker(function(cwd)
    session.restore(cwd)
  end, function(cwd)
    session.delete(cwd)
  end)
end

-- Delete current session with confirmation
function M.delete_session()
  session.delete_current()
end

-- Setup function
function M.setup(opts)
  config = vim.tbl_deep_extend('force', default_config, opts or {})

  -- Initialize session module
  session.setup()

  -- Set up keybindings
  if config.save_key and config.save_key ~= '' then
    vim.keymap.set('n', config.save_key, M.save_session, {
      desc = 'Save current session',
      silent = true,
    })
  end

  if config.load_key and config.load_key ~= '' then
    vim.keymap.set('n', config.load_key, M.load_session, {
      desc = 'Load session',
      silent = true,
    })
  end

  -- Create user commands
  vim.api.nvim_create_user_command('SessionSave', M.save_session, {
    desc = 'Save current session',
  })

  vim.api.nvim_create_user_command('SessionLoad', M.load_session, {
    desc = 'Load a session',
  })

  vim.api.nvim_create_user_command('SessionDelete', M.delete_session, {
    desc = 'Delete current session',
  })
end

return M
