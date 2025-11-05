-- ui.lua: Beautiful session picker for retrospect.nvim
local session = require('retrospect.session')
local utils = require('retrospect.utils')
local M = {}

-- Beautiful session picker with smooth UX
function M.show_session_picker(on_select, on_delete)
  local sessions = session.list()

  if #sessions == 0 then
    vim.notify('No sessions found. Create one with your save key!', vim.log.levels.WARN)
    return
  end

  -- Create display items with formatting
  local display_items = {}
  local max_len = 0
  for _, path in ipairs(sessions) do
    local formatted = utils.format_path_display(path)
    table.insert(display_items, formatted)
    max_len = math.max(max_len, #formatted)
  end

  -- Create buffer
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, display_items)
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].bufhidden = 'wipe'
  vim.bo[bufnr].filetype = 'retrospect'

  -- Calculate window size dynamically
  local width = math.min(math.max(max_len + 4, 60), vim.o.columns - 4)
  local height = math.min(#display_items, math.floor(vim.o.lines * 0.6))

  -- Create centered window with nice styling
  local win_id = vim.api.nvim_open_win(bufnr, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = 'minimal',
    border = 'rounded',
    title = ' Sessions (MRU) ',
    title_pos = 'center',
    footer = ' <CR> Open | d Delete | <Esc> Close ',
    footer_pos = 'center',
  })

  -- Window options for better UX
  vim.wo[win_id].cursorline = true
  vim.wo[win_id].number = false
  vim.wo[win_id].relativenumber = false
  vim.wo[win_id].wrap = false

  -- Highlight the floating window
  vim.api.nvim_win_set_hl_ns(win_id, vim.api.nvim_create_namespace('RetrospectPicker'))

  -- Helper to close picker
  local function close_picker()
    if vim.api.nvim_win_is_valid(win_id) then
      vim.api.nvim_win_close(win_id, true)
    end
  end

  -- Select current line
  local function select_current()
    local line = vim.api.nvim_win_get_cursor(win_id)[1]
    local selected = sessions[line]
    close_picker()
    if selected and on_select then
      vim.schedule(function()
        on_select(selected)
      end)
    end
  end

  -- Delete current line
  local function delete_current()
    local line = vim.api.nvim_win_get_cursor(win_id)[1]
    local selected = sessions[line]

    if not selected then
      return
    end

    -- Confirm deletion
    vim.ui.input({
      prompt = 'Delete "' .. utils.format_path_display(selected) .. '"? (yes/no): ',
    }, function(input)
      if input == 'yes' then
        -- Delete the session
        if on_delete then
          on_delete(selected)
        end

        -- Refresh the picker
        close_picker()
        vim.schedule(function()
          M.show_session_picker(on_select, on_delete)
        end)
      end
    end)
  end

  -- Set keymaps for intuitive navigation
  local opts = { buffer = bufnr, nowait = true, silent = true }

  -- Selection
  vim.keymap.set('n', '<CR>', select_current, opts)
  vim.keymap.set('n', 'l', select_current, opts)

  -- Close
  vim.keymap.set('n', '<Esc>', close_picker, opts)
  vim.keymap.set('n', 'q', close_picker, opts)
  vim.keymap.set('n', '<C-c>', close_picker, opts)
  vim.keymap.set('n', 'h', close_picker, opts)

  -- Delete
  vim.keymap.set('n', 'd', delete_current, opts)
  vim.keymap.set('n', 'x', delete_current, opts)
  vim.keymap.set('n', '<Del>', delete_current, opts)
end

return M
