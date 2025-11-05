-- init.lua: Main entry point for retrospect.nvim
local session = require('retrospect.session')
local ui = require('retrospect.ui')
local M = {}

-- Default configuration
local default_config = {
  save_key = '<leader>\\',
  load_key = '<leader><BS>',
  autosave = false,      -- Autosave session on BufWritePost
  autorestore = false,   -- Auto-restore last session on startup (when nvim opened with no args)
  git_branch_sessions = false, -- Separate sessions per git branch
}

local config = {}
local autosave_group = nil

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

-- Open Neovim config directory
function M.open_config()
  local config_dir = vim.fn.stdpath('config')
  vim.cmd('cd ' .. vim.fn.fnameescape(config_dir))
  vim.notify('Changed directory to: ' .. config_dir, vim.log.levels.INFO)
end

-- Setup function
function M.setup(opts)
  config = vim.tbl_deep_extend('force', default_config, opts or {})

  -- Initialize session module with config
  session.setup({
    git_branch_sessions = config.git_branch_sessions,
  })

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

  -- Set up autosave if enabled
  if config.autosave then
    autosave_group = vim.api.nvim_create_augroup('RetrospectAutosave', { clear = true })
    vim.api.nvim_create_autocmd('BufWritePost', {
      group = autosave_group,
      callback = function()
        -- Only autosave if we're in a valid session directory
        local cwd = vim.fn.getcwd()
        local utils = require('retrospect.utils')
        if not utils.is_config_dir(cwd) then
          session.save()
        end
      end,
      desc = 'Autosave session on file write',
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

  vim.api.nvim_create_user_command('SessionConfig', M.open_config, {
    desc = 'Open Neovim config directory',
  })

  -- Auto-restore last session if enabled and nvim opened with no args
  if config.autorestore then
    vim.api.nvim_create_autocmd('VimEnter', {
      nested = true,
      callback = function()
        -- Only autorestore if:
        -- 1. No files were opened
        -- 2. stdin is not being read
        -- 3. Current directory is not config directory
        if vim.fn.argc() == 0 and not vim.g.started_by_firenvim then
          local sessions = session.list()
          if #sessions > 0 then
            local utils = require('retrospect.utils')
            if not utils.is_config_dir(vim.fn.getcwd()) then
              -- Restore the most recently used session (first in list)
              vim.schedule(function()
                session.restore(sessions[1])
              end)
            end
          end
        end
      end,
      desc = 'Auto-restore last session on startup',
    })
  end
end

return M
