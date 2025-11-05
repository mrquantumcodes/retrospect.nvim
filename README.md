# Retrospect.nvim

![App Screenshot](https://github.com/mrquantumcodes/retrospect.nvim/blob/main/demo.gif)

**Zero-dependency, blazing-fast session management for Neovim.**

Retrospect.nvim is a modern Neovim plugin that makes session management effortless. Save and restore your work instantly with automatic naming, MRU ordering, and perfect buffer state preservation.

## Features

- **Zero dependencies** - Works out of the box with pure Neovim
- **Automatic session naming** - Sessions named by working directory, zero config
- **MRU session ordering** - Most recently used sessions always on top
- **Complete state restoration** - Restores buffers, windows, splits, tabs, cursor positions, and folds
- **Lightning fast** - Pure vim sessions under the hood, blazing fast save/restore
- **Beautiful UI** - Clean floating window picker with intuitive keybindings
- **Safe by design** - Prevents accidental config directory sessions


## Installation

### lazy.nvim

```lua
{
  "mrquantumcodes/retrospect.nvim",
  config = function()
    require("retrospect").setup()
  end,
}
```

### packer.nvim

```lua
use {
  "mrquantumcodes/retrospect.nvim",
  config = function()
    require("retrospect").setup()
  end,
}
```

### vim-plug

```vim
Plug 'mrquantumcodes/retrospect.nvim'
```

Then in your `init.lua`:

```lua
require("retrospect").setup()
```

## Configuration

```lua
require("retrospect").setup({
  save_key = "<leader>\\",  -- Keybinding to save session (default: <leader>\)
  load_key = "<leader><BS>", -- Keybinding to load session (default: <leader><BS>)
  autosave = false,          -- Autosave session on every file write (default: false)
})
```

**Options:**
- `save_key` - Keybinding to save session. Set to `""` to disable.
- `load_key` - Keybinding to load session. Set to `""` to disable.
- `autosave` - When `true`, automatically saves session after every file write.

## Usage

### Keybindings (default)

- `<leader>\` - Save current session
- `<leader><BS>` - Open session picker

### Session Picker Navigation

- `<CR>` or `l` - Open selected session
- `d` or `x` or `<Del>` - Delete selected session
- `<Esc>` or `q` or `h` - Close picker

### Commands

```vim
:SessionSave      " Save current session
:SessionLoad      " Open session picker
:SessionDelete    " Delete current session (with confirmation)
:SessionConfig    " Open Neovim config directory
```

### Lua API

```lua
local retrospect = require("retrospect")

-- Save current session
retrospect.save_session()

-- Load a session (opens picker)
retrospect.load_session()

-- Delete current session
retrospect.delete_session()

-- Open config directory
retrospect.open_config()
```



## Contributing

Contributions to Retrospect.nvim are welcome! If you'd like to contribute, please follow our contribution guidelines (link to CONTRIBUTING.md).


## License

This project is licensed under the GPL-3.0 License - see the LICENSE file for details.


## Contact

For bug reports, feature requests, or general inquiries, please open an issue on GitHub.

---

Happy coding with Retrospect.nvim! 🚀
