-- session.lua: Core session management for retrospect.nvim
local utils = require('retrospect.utils')
local M = {}

-- State management
local state = {
  sessions_index = {}, -- List of session paths in MRU order
  current_session = nil,
}

-- Get session file paths
local function get_session_paths(cwd)
  local session_dir = utils.get_session_dir()
  local encoded = utils.encode_path(cwd)
  return {
    vim_session = session_dir .. '/' .. encoded .. '.vim',
    metadata = session_dir .. '/' .. encoded .. '.meta',
  }
end

-- Load sessions index (MRU ordered list)
local function load_sessions_index()
  local session_dir = utils.get_session_dir()
  local index_file = session_dir .. '/index.json'

  if vim.fn.filereadable(index_file) == 1 then
    local content = vim.fn.readfile(index_file)
    local ok, data = pcall(vim.json.decode, table.concat(content, '\n'))
    if ok and data and data.sessions then
      state.sessions_index = data.sessions
      return
    end
  end

  -- Build index from existing sessions
  state.sessions_index = {}
  local session_files = vim.fn.glob(session_dir .. '/*.vim', false, true)
  for _, file in ipairs(session_files) do
    local encoded = vim.fn.fnamemodify(file, ':t:r')
    local path = utils.decode_path(encoded)
    if vim.fn.isdirectory(path) == 1 then
      table.insert(state.sessions_index, path)
    end
  end
end

-- Save sessions index
local function save_sessions_index()
  local session_dir = utils.get_session_dir()
  local index_file = session_dir .. '/index.json'

  local data = vim.json.encode({ sessions = state.sessions_index })
  vim.fn.writefile({ data }, index_file)
end

-- Update MRU order for a session
local function update_session_mru(cwd)
  -- Remove if exists
  for i, path in ipairs(state.sessions_index) do
    if path == cwd then
      table.remove(state.sessions_index, i)
      break
    end
  end

  -- Add to front (most recently used)
  table.insert(state.sessions_index, 1, cwd)

  -- Keep only existing directories
  local filtered = {}
  for _, path in ipairs(state.sessions_index) do
    if vim.fn.isdirectory(path) == 1 then
      table.insert(filtered, path)
    end
  end
  state.sessions_index = filtered

  save_sessions_index()
end

-- Save session metadata
local function save_metadata(cwd)
  local paths = get_session_paths(cwd)
  local metadata = {
    cwd = cwd,
    saved_at = os.time(),
    nvim_version = vim.version(),
  }

  vim.fn.writefile({ vim.json.encode(metadata) }, paths.metadata)
end

-- Save current session
function M.save()
  local cwd = vim.fn.getcwd()

  -- Don't save config directory sessions
  if utils.is_config_dir(cwd) then
    vim.notify('Cannot create session for Neovim config directory', vim.log.levels.WARN)
    return false
  end

  utils.ensure_session_dir()
  utils.close_special_buffers()

  local paths = get_session_paths(cwd)

  -- Save vim session (handles everything: buffers, windows, splits, cursor positions, folds, etc.)
  vim.cmd('mksession! ' .. vim.fn.fnameescape(paths.vim_session))

  -- Save metadata
  save_metadata(cwd)

  -- Update MRU index
  update_session_mru(cwd)

  state.current_session = cwd
  vim.notify('Session saved: ' .. utils.format_path_display(cwd), vim.log.levels.INFO)
  return true
end

-- Restore a session
function M.restore(cwd)
  local paths = get_session_paths(cwd)

  if vim.fn.filereadable(paths.vim_session) == 0 then
    vim.notify('Session not found: ' .. utils.format_path_display(cwd), vim.log.levels.ERROR)
    return false
  end

  -- Source the vim session (restores EVERYTHING: buffers, windows, splits, tabs, cursor positions, folds, etc.)
  local ok, err = pcall(vim.cmd, 'source ' .. vim.fn.fnameescape(paths.vim_session))
  if not ok then
    vim.notify('Failed to restore session: ' .. tostring(err), vim.log.levels.ERROR)
    return false
  end

  -- Update MRU index
  update_session_mru(cwd)

  state.current_session = cwd
  vim.notify('Session restored: ' .. utils.format_path_display(cwd), vim.log.levels.INFO)
  return true
end

-- Delete a session
function M.delete(cwd)
  local paths = get_session_paths(cwd)

  -- Delete all session files
  for _, file in pairs(paths) do
    if vim.fn.filereadable(file) == 1 then
      vim.fn.delete(file)
    end
  end

  -- Remove from index
  for i, path in ipairs(state.sessions_index) do
    if path == cwd then
      table.remove(state.sessions_index, i)
      break
    end
  end
  save_sessions_index()

  if state.current_session == cwd then
    state.current_session = nil
  end

  vim.notify('Session deleted: ' .. utils.format_path_display(cwd), vim.log.levels.INFO)
  return true
end

-- Delete current session with confirmation
function M.delete_current()
  local current = vim.v.this_session
  if current == '' then
    vim.notify('No active session to delete', vim.log.levels.WARN)
    return false
  end

  -- Extract cwd from session path
  local session_dir = utils.get_session_dir()
  local encoded = vim.fn.fnamemodify(current, ':t:r')
  local cwd = utils.decode_path(encoded)

  vim.ui.input({ prompt = 'Delete session? Type "yes" to confirm: ' }, function(input)
    if input == 'yes' then
      M.delete(cwd)
    else
      vim.notify('Session deletion cancelled', vim.log.levels.INFO)
    end
  end)

  return true
end

-- Get list of all sessions in MRU order
function M.list()
  load_sessions_index()
  return vim.deepcopy(state.sessions_index)
end

-- Initialize session module
function M.setup()
  utils.ensure_session_dir()
  load_sessions_index()
end

return M
