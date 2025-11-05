-- ui.lua: Fuzzy picker for retrospect.nvim
local session = require('retrospect.session')
local utils = require('retrospect.utils')
local fuzzy = require('retrospect.fuzzy')
local M = {}

-- Active picker state
local state = {
  sessions = {},
  filtered_sessions = {},
  current_query = "",
  selected_index = 1,
  prompt_bufnr = nil,
  prompt_winid = nil,
  results_bufnr = nil,
  results_winid = nil,
  preview_bufnr = nil,
  preview_winid = nil,
  on_select = nil,
  on_delete = nil,
}

-- Format time ago (e.g., "2h ago", "3d ago")
local function format_time_ago(timestamp)
  local now = os.time()
  local diff = now - timestamp

  if diff < 60 then
    return 'just now'
  elseif diff < 3600 then
    return math.floor(diff / 60) .. 'm ago'
  elseif diff < 86400 then
    return math.floor(diff / 3600) .. 'h ago'
  elseif diff < 604800 then
    return math.floor(diff / 86400) .. 'd ago'
  else
    return os.date('%b %d', timestamp)
  end
end

-- Update preview window with session info
local function update_preview()
  if not state.preview_bufnr or not vim.api.nvim_buf_is_valid(state.preview_bufnr) then
    return
  end

  if #state.filtered_sessions == 0 then
    vim.api.nvim_buf_set_option(state.preview_bufnr, 'modifiable', true)
    vim.api.nvim_buf_set_lines(state.preview_bufnr, 0, -1, false, { 'No sessions selected' })
    vim.api.nvim_buf_set_option(state.preview_bufnr, 'modifiable', false)
    return
  end

  local selected = state.filtered_sessions[state.selected_index]
  if not selected then
    return
  end

  local lines = {}

  -- Special handling for --CONFIG--
  if selected.session_id == '--CONFIG--' then
    table.insert(lines, 'Open Neovim configuration directory')
    table.insert(lines, '')
    table.insert(lines, 'Location: ' .. vim.fn.stdpath('config'))
  else
    local metadata = session.get_metadata(selected.session_id)

    if metadata and metadata.buffers and #metadata.buffers > 0 then
      table.insert(lines, 'Files in session (' .. #metadata.buffers .. '):')
      table.insert(lines, '')

      -- Show up to 20 files
      local max_files = math.min(20, #metadata.buffers)
      for i = 1, max_files do
        local filepath = metadata.buffers[i]
        -- Make path relative to session cwd for readability
        local relative = filepath:gsub('^' .. vim.pesc(selected.session_id) .. '/', '')
        table.insert(lines, '  ' .. relative)
      end

      if #metadata.buffers > max_files then
        table.insert(lines, '')
        table.insert(lines, '  ... and ' .. (#metadata.buffers - max_files) .. ' more files')
      end
    else
      table.insert(lines, 'No file information available')
      table.insert(lines, '')
      table.insert(lines, 'Save the session to see files')
    end
  end

  vim.api.nvim_buf_set_option(state.preview_bufnr, 'modifiable', true)
  vim.api.nvim_buf_set_lines(state.preview_bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(state.preview_bufnr, 'modifiable', false)
end

-- Update the filtered results based on current query
local function update_results()
  local query = state.current_query

  -- Filter sessions using fuzzy matching
  state.filtered_sessions = fuzzy.filter(state.sessions, query)

  -- Build display lines
  local display_lines = {}
  for _, item in ipairs(state.filtered_sessions) do
    table.insert(display_lines, item.display_text)
  end

  -- Update results buffer
  if state.results_bufnr and vim.api.nvim_buf_is_valid(state.results_bufnr) then
    vim.api.nvim_buf_set_option(state.results_bufnr, 'modifiable', true)
    vim.api.nvim_buf_set_lines(state.results_bufnr, 0, -1, false, display_lines)
    vim.api.nvim_buf_set_option(state.results_bufnr, 'modifiable', false)
  end

  -- Reset selection to first item
  state.selected_index = 1

  -- Update cursor position in results window
  if state.results_winid and vim.api.nvim_win_is_valid(state.results_winid) and #state.filtered_sessions > 0 then
    pcall(vim.api.nvim_win_set_cursor, state.results_winid, {1, 0})
  end

  -- Update preview
  update_preview()
end

-- Move selection up/down
local function move_selection(direction)
  if #state.filtered_sessions == 0 then
    return
  end

  local new_index = state.selected_index + direction

  -- Wrap around
  if new_index < 1 then
    new_index = #state.filtered_sessions
  elseif new_index > #state.filtered_sessions then
    new_index = 1
  end

  state.selected_index = new_index

  -- Update cursor in results window
  if state.results_winid and vim.api.nvim_win_is_valid(state.results_winid) then
    pcall(vim.api.nvim_win_set_cursor, state.results_winid, {new_index, 0})
  end

  -- Update preview
  update_preview()
end

-- Close the picker
local function close_picker()
  -- Close all windows
  if state.prompt_winid and vim.api.nvim_win_is_valid(state.prompt_winid) then
    pcall(vim.api.nvim_win_close, state.prompt_winid, true)
  end

  if state.results_winid and vim.api.nvim_win_is_valid(state.results_winid) then
    pcall(vim.api.nvim_win_close, state.results_winid, true)
  end

  if state.preview_winid and vim.api.nvim_win_is_valid(state.preview_winid) then
    pcall(vim.api.nvim_win_close, state.preview_winid, true)
  end

  -- Clear state
  state = {
    sessions = {},
    filtered_sessions = {},
    current_query = "",
    selected_index = 1,
    prompt_bufnr = nil,
    prompt_winid = nil,
    results_bufnr = nil,
    results_winid = nil,
    preview_bufnr = nil,
    preview_winid = nil,
    on_select = nil,
    on_delete = nil,
  }
end

-- Select current item
local function select_item()
  if #state.filtered_sessions == 0 then
    close_picker()
    return
  end

  local selected = state.filtered_sessions[state.selected_index]

  if selected and state.on_select then
    local callback = state.on_select
    local session_id = selected.session_id
    close_picker()
    vim.schedule(function()
      callback(session_id)
    end)
  end
end

-- Delete current item
local function delete_item()
  if #state.filtered_sessions == 0 then
    return
  end

  local selected = state.filtered_sessions[state.selected_index]
  if not selected then
    return
  end

  -- Confirm deletion
  vim.ui.input({
    prompt = 'Delete "' .. utils.format_path_display(selected.session_id) .. '"? (yes/no): ',
  }, function(input)
    if input == 'yes' and state.on_delete then
      state.on_delete(selected.session_id)
      -- Refresh picker
      close_picker()
      vim.schedule(function()
        M.show_session_picker(state.on_select, state.on_delete)
      end)
    end
  end)
end

-- Setup keymaps for the picker
local function setup_keymaps()
  local prompt_bufnr = state.prompt_bufnr
  local results_bufnr = state.results_bufnr

  -- Escape to close
  vim.keymap.set({'n', 'i'}, '<Esc>', close_picker, { buffer = prompt_bufnr, silent = true })
  vim.keymap.set({'n', 'i'}, '<C-c>', close_picker, { buffer = prompt_bufnr, silent = true })

  -- Enter to select
  vim.keymap.set({'n', 'i'}, '<CR>', select_item, { buffer = prompt_bufnr, silent = true })

  -- Navigation
  vim.keymap.set('i', '<C-n>', function() move_selection(1) end, { buffer = prompt_bufnr, silent = true })
  vim.keymap.set('i', '<C-p>', function() move_selection(-1) end, { buffer = prompt_bufnr, silent = true })
  vim.keymap.set('i', '<Down>', function() move_selection(1) end, { buffer = prompt_bufnr, silent = true })
  vim.keymap.set('i', '<Up>', function() move_selection(-1) end, { buffer = prompt_bufnr, silent = true })

  -- Delete
  vim.keymap.set({'n', 'i'}, '<C-d>', delete_item, { buffer = prompt_bufnr, silent = true })

  -- Results window keymaps
  if results_bufnr then
    vim.keymap.set('n', 'j', function() move_selection(1) end, { buffer = results_bufnr, silent = true })
    vim.keymap.set('n', 'k', function() move_selection(-1) end, { buffer = results_bufnr, silent = true })
    vim.keymap.set('n', '<CR>', select_item, { buffer = results_bufnr, silent = true })
    vim.keymap.set('n', '<Esc>', close_picker, { buffer = results_bufnr, silent = true })
    vim.keymap.set('n', 'd', delete_item, { buffer = results_bufnr, silent = true })
  end
end

-- Setup prompt callback for live filtering
local function setup_prompt_callback()
  -- Setup autocmd for text changes
  vim.api.nvim_create_autocmd({'TextChanged', 'TextChangedI'}, {
    buffer = state.prompt_bufnr,
    callback = function()
      -- Get current line text (skip the prompt prefix "> ")
      local lines = vim.api.nvim_buf_get_lines(state.prompt_bufnr, 0, 1, false)
      if #lines > 0 then
        local line = lines[1]
        local query = line:sub(3)  -- Skip "> "

        if query ~= state.current_query then
          state.current_query = query
          update_results()
        end
      end
    end,
  })
end

-- Show session picker with fuzzy search
function M.show_session_picker(on_select, on_delete)
  local session_list = session.list()

  if #session_list == 0 then
    vim.notify('No sessions found. Create one with your save key!', vim.log.levels.WARN)
    return
  end

  -- Build session items with display text
  local items = {}
  for _, session_id in ipairs(session_list) do
    local metadata = session.get_metadata(session_id)
    local formatted = utils.format_path_display(session_id)

    -- Build info string with stats
    local info = ''
    if metadata then
      local time_ago = format_time_ago(metadata.saved_at)

      -- Add file count if available
      local stats = ''
      if metadata.buffers and #metadata.buffers > 0 then
        stats = #metadata.buffers .. ' file' .. (#metadata.buffers > 1 and 's' or '')
      end

      if stats ~= '' then
        info = ' │ ' .. stats .. ' │ ' .. time_ago
      else
        info = ' │ ' .. time_ago
      end
    end

    local display_text = formatted .. info

    table.insert(items, {
      session_id = session_id,
      display_text = display_text,
      match_text = formatted,  -- Match against path only, not stats/time
    })
  end

  -- Initialize state
  state.sessions = items
  state.filtered_sessions = fuzzy.filter(items, "")
  state.current_query = ""
  state.selected_index = 1
  state.on_select = on_select
  state.on_delete = on_delete

  -- Calculate window positions
  local editor_width = vim.o.columns
  local editor_height = vim.o.lines

  local total_width = math.min(120, math.floor(editor_width * 0.9))
  local height = math.min(25, math.floor(editor_height * 0.7))

  local results_width = math.floor(total_width * 0.4)
  local preview_width = total_width - results_width - 2

  local start_col = math.floor((editor_width - total_width) / 2)
  local start_row = math.floor((editor_height - height) / 2)

  -- Create prompt buffer
  state.prompt_bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(state.prompt_bufnr, 'buftype', 'prompt')
  vim.api.nvim_buf_set_option(state.prompt_bufnr, 'bufhidden', 'wipe')
  vim.fn.prompt_setprompt(state.prompt_bufnr, '> ')

  -- Create prompt window (full width)
  state.prompt_winid = vim.api.nvim_open_win(state.prompt_bufnr, true, {
    relative = 'editor',
    width = total_width,
    height = 1,
    row = start_row,
    col = start_col,
    style = 'minimal',
    border = 'rounded',
    title = ' Search Sessions ',
    title_pos = 'center',
  })

  -- Create results buffer
  state.results_bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(state.results_bufnr, 'modifiable', false)
  vim.api.nvim_buf_set_option(state.results_bufnr, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(state.results_bufnr, 'filetype', 'retrospect')

  -- Create results window (left side)
  state.results_winid = vim.api.nvim_open_win(state.results_bufnr, false, {
    relative = 'editor',
    width = results_width,
    height = height - 3,
    row = start_row + 3,
    col = start_col,
    style = 'minimal',
    border = 'rounded',
    title = ' Sessions ',
    title_pos = 'center',
    footer = ' <CR> Open | <C-d> Delete | <Esc> Close ',
    footer_pos = 'center',
  })

  vim.api.nvim_win_set_option(state.results_winid, 'cursorline', true)

  -- Create preview buffer
  state.preview_bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(state.preview_bufnr, 'modifiable', false)
  vim.api.nvim_buf_set_option(state.preview_bufnr, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(state.preview_bufnr, 'filetype', 'retrospect')

  -- Create preview window (right side)
  state.preview_winid = vim.api.nvim_open_win(state.preview_bufnr, false, {
    relative = 'editor',
    width = preview_width,
    height = height - 3,
    row = start_row + 3,
    col = start_col + results_width + 2,
    style = 'minimal',
    border = 'rounded',
    title = ' Preview ',
    title_pos = 'center',
  })

  -- Setup keymaps
  setup_keymaps()

  -- Setup prompt callback
  setup_prompt_callback()

  -- Initial results display
  update_results()

  -- Focus prompt window and enter insert mode
  vim.api.nvim_set_current_win(state.prompt_winid)
  vim.cmd('startinsert!')
end

return M
