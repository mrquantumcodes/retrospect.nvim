-- utils.lua: Modern utility functions for retrospect.nvim
local M = {}

-- Get the session directory path
function M.get_session_dir()
  return vim.fs.normalize(vim.fn.stdpath('data') .. '/retrospect_sessions')
end

-- Ensure session directory exists
function M.ensure_session_dir()
  local dir = M.get_session_dir()
  vim.fn.mkdir(dir, 'p')
  return dir
end

-- Encode a path to a safe filename (using base64-like encoding)
function M.encode_path(path)
  local normalized = vim.fs.normalize(path)
  -- Simple hex encoding to avoid filesystem issues
  local encoded = normalized:gsub('.', function(c)
    return string.format('%02x', string.byte(c))
  end)
  return encoded
end

-- Decode a filename back to path
function M.decode_path(encoded)
  local decoded = encoded:gsub('..', function(hex)
    return string.char(tonumber(hex, 16))
  end)
  return decoded
end

-- Get all valid file buffers (excluding special buffers)
function M.get_file_buffers()
  local buffers = {}
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buflisted then
      local buftype = vim.bo[bufnr].buftype
      local bufname = vim.api.nvim_buf_get_name(bufnr)
      -- Only include normal file buffers
      if buftype == '' and bufname ~= '' and vim.fn.filereadable(bufname) == 1 then
        table.insert(buffers, bufnr)
      end
    end
  end
  return buffers
end

-- Get buffer list in MRU order (most recently used first)
function M.get_buffers_mru()
  local buffers = M.get_file_buffers()

  -- Sort by last used time (using buffer's lastused timestamp)
  table.sort(buffers, function(a, b)
    local a_time = vim.fn.getbufinfo(a)[1].lastused
    local b_time = vim.fn.getbufinfo(b)[1].lastused
    return a_time > b_time
  end)

  return buffers
end

-- Get buffer paths in MRU order
function M.get_buffer_paths_mru()
  local buffers = M.get_buffers_mru()
  local paths = {}

  for _, bufnr in ipairs(buffers) do
    local path = vim.api.nvim_buf_get_name(bufnr)
    if path ~= '' then
      table.insert(paths, vim.fs.normalize(path))
    end
  end

  return paths
end

-- Close all non-file buffers before saving session
function M.close_special_buffers()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local buftype = vim.bo[bufnr].buftype
      -- Close any non-normal buffers (terminal, quickfix, help, etc.)
      if buftype ~= '' then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end
  end
end

-- Check if path is the neovim config directory
function M.is_config_dir(path)
  local config_dir = vim.fs.normalize(vim.fn.stdpath('config'))
  local check_dir = vim.fs.normalize(path)
  return config_dir == check_dir
end

-- Format path for display (shorten home directory)
function M.format_path_display(path)
  local home = vim.fn.expand('~')
  if path:sub(1, #home) == home then
    return '~' .. path:sub(#home + 1)
  end
  return path
end

return M
