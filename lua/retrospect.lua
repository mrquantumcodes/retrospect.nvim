-- Function to encode a path to a reversible string
local M = {}

M.opts = {}

CurrSessionCwd = ""

should_reorder = false

session_dir = vim.fn.stdpath('data'):gsub("\\", "/") .. "/nvim_sessions/"

M.setup = function(options)
  M.opts = options

  M.opts.style = options.style or "modern"

  local keybinding = options.saveKey or "<Leader>\\"
  local loadbinding = options.loadKey or "<Leader><BS>"

  should_reorder = options.auto_buffer_reorder or false

  if loadbinding ~= "NONE" then
    vim.api.nvim_set_keymap('n', loadbinding, "",
      { noremap = true, silent = true, callback = function() M.RestoreSession() end })
  end

  if keybinding ~= "NONE" then
    vim.api.nvim_set_keymap('n', keybinding, "",
      { noremap = true, silent = true, callback = function() M.SaveSession() end })
  end
end

function pathToFilename(path)
  local encoded = ""
  for i = 1, #path do
    encoded = encoded .. string.byte(path, i) .. "_"
  end
  return encoded
end

-- Function to decode a reversible string back to a path
function filenameToPath(filename)
  local decoded = ""
  local parts = {}
  for part in filename:gmatch("[^_]+") do
    table.insert(parts, tonumber(part))
  end
  for _, value in ipairs(parts) do
    decoded = decoded .. string.char(value)
  end
  return decoded
end

function closeNonFileBuffers()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    vim.api.nvim_buf_call(bufnr, function()
      local buftype = vim.bo.filetype
      -- print(buftype)

      if buftype == 'netrw' then
        -- Close the buffer
        vim.cmd(':bdelete! ' .. tostring(bufnr))
      end
    end)


    -- Check if the buffer is non-file (e.g., NERDTree or UndoTree)
  end
end

-- Function to save the current session with a name based on the current working directory
M.SaveSession = function()
  -- vim.cmd("NERDTreeClose")
  -- vim.cmd("UndotreeHide")

  closeNonFileBuffers()

  if vim.fn.getcwd():gsub("\\", "/"):gsub("~", vim.fn.expand("$HOME")) == vim.fn['stdpath']('config'):gsub("\\", "/"):gsub("~", vim.fn.expand("$HOME")) then
    print("Cannot create a session for the Neovim config folder")
    return
  end

  -- Create the session directory if it doesn't exist
  createSessionDirectory()

  -- Get the current working directory and replace slashes with double underscores
  local cwd = pathToFilename(vim.fn.getcwd())
  local session_path = session_dir .. cwd .. ".vim"
  vim.cmd("mksession! " .. session_path)

  local session_buf_order_path = session_dir .. cwd .. ".buforder"
  file = io.open(session_buf_order_path, "w+")
  io.output(file)
  io.write(vim.fn.execute("ls t"))
  io.close(file)

  -- Update the sessions_list.txt file
  local sessions_list_path = session_dir .. "sessions_list.txt"
  updateSessionsList(sessions_list_path, cwd)

  print("Session saved")
end

-- Function to create the session directory if it doesn't exist
function createSessionDirectory()
  local session_dir_exists = vim.fn.isdirectory(session_dir)
  if session_dir_exists == 0 then
    vim.fn.mkdir(session_dir, "p")
  end
end

-- Function to update sessions_list.txt
function updateSessionsList(file_path, current_session_name)
  local sessions = {} -- Table to store session names

  -- Set the first item to the current session name by default
  table.insert(sessions, current_session_name .. ".vim")

  -- Get a list of .vim files in the session directory
  local vim_files = vim.fn.glob(session_dir .. "*.vim", true, true)

  -- Extract and add session names from file paths
  for _, file in ipairs(vim_files) do
    local session_name = vim.fn.fnamemodify(file, ":t")
    if session_name and session_name ~= current_session_name .. ".vim" then
      table.insert(sessions, session_name)
    end
  end

  -- Write the updated session list to sessions_list.txt
  local file = io.open(file_path, "w")
  if file then
    for _, session in ipairs(sessions) do
      file:write(session .. "\n")
    end
    file:close()
  else
    print("Error: Could not open " .. file_path .. " for writing.")
  end
end

function ignoreProblematicBuffers()
  --   local num_buffers = vim.fn.bufnr('$')
  -- for l = 1, num_buffers do
  --     if vim.fn.bufwinnr(l) == -1 then
  --         vim.api.nvim_command('sbuffer ' .. l)
  --     end
  -- end
end

-- Function to restore a session from the selected session file

shouldDeleteWindow = false

M.RestoreSession = function()
  shouldDeleteWindow = true

  if vim.fn.isdirectory(session_dir) == 0 or vim.fn['filereadable'](session_dir .. "sessions_list.txt") == 0 then
    print("No session has been created yet")
    return
  end


  local sessions_list_path = session_dir .. "sessions_list.txt"
  local sessions_list = vim.fn.readfile(sessions_list_path)

  if #sessions_list == 0 then
    print("No session files found in " .. session_dir)
    return
  end

  local slist = {};

  for k, v in pairs(sessions_list) do
    table.insert(slist, filenameToPath(v))
  end

  if pcall(require, 'dressing') and M.opts.style == "modern" then
    vim.ui.select(slist, {
      prompt = "Select a session to restore",
    }, function(selected)
      shouldDeleteWindow = false
      if selected ~= "" and selected ~= nil then
        vim.cmd('bufdo bd')

        CurrSessionCwd = pathToFilename(selected:gsub(".vim", ""))

        local session_path = session_dir .. pathToFilename(selected:gsub(".vim", "")) .. ".vim"
        vim.cmd("so " .. session_path)

        ignoreProblematicBuffers()

        local sessions_list_path = session_dir .. "sessions_list.txt"
        updateSessionsList(sessions_list_path, pathToFilename(selected:gsub(".vim", "")))

        print("Session restored")

        if should_reorder then
          -- ReorderBuffers()
        end

        -- statusline()
      end
    end)
  elseif pcall(require, 'telescope') and M.opts.style == "telescope" then
    local action_state = require("telescope.actions.state")
    local action_utils = require("telescope.actions.utils")
    local entry_display = require("telescope.pickers.entry_display")
    local finders = require("telescope.finders")
    local pickers = require("telescope.pickers")
    local conf = require("telescope.config").values

    -- new telescope picker
    pickers.new({}, {
      prompt_title = "Select a session to restore",
      finder = finders.new_table {
        results = slist,
        entry_maker = function(entry)
          return {
            display = entry,
            value = entry,
            ordinal = entry,
          }
        end,
      },
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        local restore_session = function()
          local selection = action_state.get_selected_entry()
          if selection then
            local selected = selection.value

            if selected ~= "" and selected ~= nil then
              vim.cmd('bufdo! bd')

              CurrSessionCwd = pathToFilename(selected:gsub(".vim", ""))

              local session_path = session_dir .. pathToFilename(selected:gsub(".vim", "")) .. ".vim"
              vim.cmd("so " .. session_path)

              ignoreProblematicBuffers()

              local sessions_list_path = session_dir .. "sessions_list.txt"
              updateSessionsList(sessions_list_path, pathToFilename(selected:gsub(".vim", "")))

              print("Session restored")

              if should_reorder then
                -- ReorderBuffers()
              end

              -- statusline()
            end
          end
        end

        map("i", "<CR>", restore_session)
        map("n", "<CR>", restore_session)

        return true
      end,
    }):find()
  else
    local bufnr = vim.api.nvim_create_buf(false, true)

    -- Set the buffer contents to the list of buffer paths
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, slist)

    -- Create a window for the buffer
    local win_id = vim.api.nvim_open_win(bufnr, true, {
      relative = 'editor',
      width = 55,
      height = 10,
      row = vim.o.lines / 2 - #slist / 2 - 5,
      col = vim.o.columns / 2 - 27.5,
      style = 'minimal',
      border = 'rounded',
      title = 'Open a session',
      anchor = 'NW'
    })

    vim.api.nvim_buf_call(bufnr, function()
      vim.cmd('set nomodifiable')
      vim.cmd('set cursorline')
    end)

    -- Set key mappings for navigation and buffer opening
    vim.api.nvim_buf_set_keymap(bufnr, 'n', '<CR>', "", {
      noremap = true,
      silent = true,
      callback = function()
        local bufnr = vim.fn.bufnr('%')
        local line_number = vim.fn.line('.')
        local selected = slist[line_number]



        if selected then
          vim.api.nvim_buf_call(bufnr, function()
            vim.cmd('set modifiable')
          end)

          if shouldDeleteWindow then
            vim.cmd('bdelete! ' .. bufnr) -- Close the buffer list window
            -- vim.cmd('edit ' .. selected_path)

            -- vim.cmd('buffer ' .. selected_path)

            if selected ~= "" and selected ~= nil then
              vim.cmd('bufdo bd!')

              CurrSessionCwd = pathToFilename(selected:gsub(".vim", ""))

              local session_path = session_dir .. pathToFilename(selected:gsub(".vim", "")) .. ".vim"
              vim.cmd("so " .. session_path)

              ignoreProblematicBuffers()

              local sessions_list_path = session_dir .. "sessions_list.txt"
              updateSessionsList(sessions_list_path, pathToFilename(selected:gsub(".vim", "")))

              -- print("Session restored")

              if should_reorder then
                -- ReorderBuffers()
              end

              -- statusline()
            end

            shouldDeleteWindow = false
          end
        end
      end
    })

    -- Set key mappings for navigation and buffer opening
    vim.api.nvim_buf_set_keymap(bufnr, 'n', '<Esc><Esc>', "", {
      noremap = true,
      silent = true,
      callback = function()
        vim.api.nvim_buf_call(bufnr, function()
          vim.cmd('set modifiable')
        end)

        vim.cmd('bdelete ' .. bufnr)
      end
    })

    -- Store window ID and buffer number for later use
    vim.api.nvim_buf_set_var(bufnr, 'buffer_list_win_id', win_id)
  end
end

M.DeleteSession = function()
  sname = vim.fn.eval('v:this_session'):gsub(session_dir, "")
  -- print("\n" .. sname .. "\n")

  if sname == "" or sname == nil then
    print("You must open a session to delete it")
  else
    local confirm = vim.fn.input("Type \"yes\" to delete: ")

    if confirm == "yes" then
      local sessions = {} -- Table to store session names

      vim.fn.delete(sname)
      -- print(session_dir .. "/" .. sname)

      -- Get a list of .vim files in the session directory
      local vim_files = vim.fn.glob(session_dir .. "*.vim", true, true)

      -- Extract and add session names from file paths
      for _, file in ipairs(vim_files) do
        local session_name = vim.fn.fnamemodify(file, ":t")
        table.insert(sessions, session_name)
      end

      -- Write the updated session list to sessions_list.txt
      local file = io.open(session_dir .. "sessions_list.txt", "w")
      if file then
        for _, session in ipairs(sessions) do
          file:write(session .. "\n")
        end
        file:close()

        print("\n\n Session Deleted Successfully")
      else
        print("Error: Could not open " .. session_dir .. "sessions_list.txt" .. " for writing.")
      end
    else
      print("\n\n Session Deletion Cancelled")
    end
  end
end

vim.cmd(
  [[command! DelSession lua require"retrospect".DeleteSession() ]])


function GotoSettings()
  local conf = vim.fn['stdpath']('config')
  vim.cmd("cd " .. conf)
end

vim.cmd([[command! Nset lua GotoSettings() ]])


-- Map Leader+\ to save the current session with a name based on the cwd
vim.api.nvim_set_keymap('n', '<Leader>\\', ':lua SaveSession()<CR>', { noremap = true, silent = true })

-- Map Leader+Backspace to restore a session from a list of available sessions
vim.api.nvim_set_keymap('n', '<Leader><BS>', ':lua RestoreSession()<CR>', { noremap = true, silent = true })


function ReverseTable(t)
  local reversedTable = {}
  local itemCount = #t
  for k, v in ipairs(t) do
    reversedTable[itemCount + 1 - k] = v
  end
  return reversedTable
end

-- Define a function to reorder buffers based on the output of "ls t"
function ReorderBuffers()
  -- Run the "ls t" command and capture its output

  local sessOrder = vim.v.this_session:gsub("%.vim", "%.buforder")
  local mfile = io.open(sessOrder, "r")

  FileContents = ""

  if mfile ~= nil then
    io.input(mfile)
    FileContents = mfile:read("a")
    print(FileContents)
    mfile:close()
  end


  local ls_output = vim.split(FileContents, "\n")
  -- local ls_output = vim.split(vim.fn.execute("ls"), "\n")

  ls_output = ReverseTable(ls_output)

  -- Iterate through the list of files and open them in order
  for _, filename in ipairs(ls_output) do
    fname = filename:match("\"(.-)\"")
    if fname ~= nil and fname ~= "nil" then
      vim.cmd("bnext")          -- Switch to the next buffer
      vim.cmd("edit " .. fname) -- Open the file
    end
    print(filename:match("\"(.-)\""))
  end
end

-- Map the function to a command
vim.cmd("command! ReorderBuffers lua ReorderBuffers()")


return M
