-- session.lua: Core session management for retrospect.nvim
local utils = require('retrospect.utils')
local M = {}

-- State management
local state = {
  sessions_index = {}, -- List of session paths in MRU order
  current_session = nil,
  git_branch_sessions = false,
}

-- Get current git branch (if in a git repo)
local function get_git_branch(cwd)
  if not state.git_branch_sessions then
    return nil
  end

  local handle = io.popen('cd ' .. vim.fn.shellescape(cwd) .. ' && git rev-parse --abbrev-ref HEAD 2>/dev/null')
  if not handle then
    return nil
  end

  local branch = handle:read('*a')
  handle:close()

  if branch and branch ~= '' then
    return vim.trim(branch)
  end
  return nil
end

-- Get session identifier (cwd + optional git branch)
local function get_session_id(cwd)
  local branch = get_git_branch(cwd)
  if branch then
    return cwd .. '@' .. branch
  end
  return cwd
end

-- Get session file paths
local function get_session_paths(cwd)
  local session_dir = utils.get_session_dir()
  local session_id = get_session_id(cwd)
  local encoded = utils.encode_path(session_id)
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
    local session_id = utils.decode_path(encoded)
    -- Extract base cwd to check if directory exists
    local base_cwd = session_id:match('^(.-)@') or session_id
    if vim.fn.isdirectory(base_cwd) == 1 then
      table.insert(state.sessions_index, session_id)
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
  local session_id = get_session_id(cwd)

  -- Remove if exists
  for i, id in ipairs(state.sessions_index) do
    if id == session_id then
      table.remove(state.sessions_index, i)
      break
    end
  end

  -- Add to front (most recently used)
  table.insert(state.sessions_index, 1, session_id)

  -- Keep only valid sessions (check if base directory exists)
  local filtered = {}
  for _, id in ipairs(state.sessions_index) do
    -- Extract base cwd (remove @branch if present)
    local base_cwd = id:match('^(.-)@') or id
    if vim.fn.isdirectory(base_cwd) == 1 then
      table.insert(filtered, id)
    end
  end
  state.sessions_index = filtered

  save_sessions_index()
end

-- Save session metadata
local function save_metadata(cwd)
  local paths = get_session_paths(cwd)
  local branch = get_git_branch(cwd)

  local metadata = {
    cwd = cwd,
    git_branch = branch,
    saved_at = os.time(),
    nvim_version = vim.version(),
  }

  vim.fn.writefile({ vim.json.encode(metadata) }, paths.metadata)
end

-- Get session metadata
function M.get_metadata(session_id)
  local session_dir = utils.get_session_dir()
  local encoded = utils.encode_path(session_id)
  local metadata_file = session_dir .. '/' .. encoded .. '.meta'

  if vim.fn.filereadable(metadata_file) == 1 then
    local content = vim.fn.readfile(metadata_file)
    local ok, data = pcall(vim.json.decode, table.concat(content, '\n'))
    if ok then
      return data
    end
  end

  return nil
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
  -- vim.notify('Session saved: ' .. utils.format_path_display(cwd), vim.log.levels.INFO)
  return true
end

-- Restore a session (session_id can be "cwd" or "cwd@branch")
function M.restore(session_id)
  -- Extract base cwd for session paths
  local base_cwd = session_id:match('^(.-)@') or session_id

  local session_dir = utils.get_session_dir()
  local encoded = utils.encode_path(session_id)
  local session_file = session_dir .. '/' .. encoded .. '.vim'

  if vim.fn.filereadable(session_file) == 0 then
    vim.notify('Session not found: ' .. utils.format_path_display(session_id), vim.log.levels.ERROR)
    return false
  end

  -- Source the vim session (restores EVERYTHING: buffers, windows, splits, tabs, cursor positions, folds, etc.)
  local ok, err = pcall(vim.cmd, 'source ' .. vim.fn.fnameescape(session_file))
  if not ok then
    vim.notify('Failed to restore session: ' .. tostring(err), vim.log.levels.ERROR)
    return false
  end

  -- Update MRU index
  update_session_mru(base_cwd)

  state.current_session = session_id
  vim.notify('Session restored: ' .. utils.format_path_display(session_id), vim.log.levels.INFO)
  return true
end

-- Delete a session (session_id can be "cwd" or "cwd@branch")
function M.delete(session_id)
  local session_dir = utils.get_session_dir()
  local encoded = utils.encode_path(session_id)

  -- Delete all session files
  local files = {
    session_dir .. '/' .. encoded .. '.vim',
    session_dir .. '/' .. encoded .. '.meta',
  }

  for _, file in ipairs(files) do
    if vim.fn.filereadable(file) == 1 then
      vim.fn.delete(file)
    end
  end

  -- Remove from index
  for i, id in ipairs(state.sessions_index) do
    if id == session_id then
      table.remove(state.sessions_index, i)
      break
    end
  end
  save_sessions_index()

  if state.current_session == session_id then
    state.current_session = nil
  end

  vim.notify('Session deleted: ' .. utils.format_path_display(session_id), vim.log.levels.INFO)
  return true
end

-- Delete current session with confirmation
function M.delete_current()
  local current = vim.v.this_session
  if current == '' then
    vim.notify('No active session to delete', vim.log.levels.WARN)
    return false
  end

  -- Extract session_id from session path
  local session_dir = utils.get_session_dir()
  local encoded = vim.fn.fnamemodify(current, ':t:r')
  local session_id = utils.decode_path(encoded)

  vim.ui.input({ prompt = 'Delete session? Type "yes" to confirm: ' }, function(input)
    if input == 'yes' then
      M.delete(session_id)
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
function M.setup(opts)
  opts = opts or {}
  state.git_branch_sessions = opts.git_branch_sessions or false

  utils.ensure_session_dir()
  load_sessions_index()
end

return M
