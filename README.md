# Retrospect.nvim

Retrospect.nvim is a Neovim plugin that simplifies session management by allowing you to save and recall your recent sessions effortlessly. It presents your saved sessions in a list, ordered by last usage, making it easy to jump back to your work exactly where you left off.



## Packer Install Instruction

To install Retrospect.nvim using Packer.nvim, add the following line to your Lua configuration:

```lua
use {"mrquantumcodes/retrospect.nvim"}
```



## Setup Instruction

To configure Retrospect.nvim, add the following code to your Lua Neovim configuration:

```lua
local retrospect = require('retrospect')
retrospect.setup({
  saveKey = "<leader>\\", -- The shortcut to save the session, default is leader+backslash(\)
  loadKey = "<leader><BS>", -- The shortcut to load the session
  style = "default" -- or "modern", if you have nui.nvim and dressing.nvim
})
```

You can customize the saveKey, loadKey, and style options to fit your preferences.



## Usage

To save a session, use:

```lua
retrospect.SaveSession()
```

To load a session, use:

```lua
retrospect.LoadSession()
```

To delete the current session, use:

```lua
retrospect.DeleteSession()
```

Additionally, you can use the command :DelSession inside Neovim to delete the current session.



## Contributing

Contributions to Retrospect.nvim are welcome! If you'd like to contribute, please follow our contribution guidelines (link to CONTRIBUTING.md).


## License

This project is licensed under the GPL-3.0 License - see the LICENSE file for details.


## Contact

For bug reports, feature requests, or general inquiries, please open an issue on GitHub.

---

Happy coding with Retrospect.nvim! 🚀
