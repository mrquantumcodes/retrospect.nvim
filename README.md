# Retrospect.nvim

![App Screenshot](https://github.com/mrquantumcodes/retrospect.nvim/blob/main/demo.gif)

**Zero-dependency, blazing-fast session management for Neovim.**

Retrospect.nvim is a modern Neovim plugin that makes session management effortless. Save and restore your work instantly with automatic naming, MRU ordering, and perfect buffer state preservation.

## Features

- **Zero dependencies** - Works out of the box with pure Neovim
- **Automatic session naming** - No need to manually name sessions (based on CWD)
- **MRU ordering** - Most recently used sessions always on top
- **True buffer MRU preservation** - Maintains exact buffer usage order across restarts
- **Lightning fast** - Optimized session save/restore with modern Neovim APIs
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
})
```

**Note:** Set either key to empty string `""` to disable that keybinding.

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
```



## Contributing

Contributions to Retrospect.nvim are welcome! If you'd like to contribute, please follow our contribution guidelines (link to CONTRIBUTING.md).


## License

This project is licensed under the GPL-3.0 License - see the LICENSE file for details.


## Contact

For bug reports, feature requests, or general inquiries, please open an issue on GitHub.

---

Happy coding with Retrospect.nvim! 🚀
