# smart-im.nvim

Smart input method switcher for Neovim with per-filetype memory.

> Highly inspired by [im-select.nvim](https://github.com/keaising/im-select.nvim)

## Features

- 🎯 **Per-filetype Memory**: Automatically remembers the last used input method for each filetype
- 🔄 **Auto-restore**: Restores appropriate input method when entering insert mode
- 🌍 **Cross-platform**: Works on macOS (input sources), Linux (IBus/Fcitx), and Windows
- ⚡ **Lightweight**: Zero dependencies, pure Lua implementation
- 🔧 **Customizable**: Extensive configuration options and Lua API
- 🎮 **Fallback Logic**: Global default when no previous IM exists

## Installation

### lazy.nvim

```lua
{
  "yourusername/smart-im.nvim",
  event = "InsertEnter",
  config = function()
    require("smart-im").setup({
      -- your config here
    })
  end,
}
```

### packer.nvim

```lua
use {
  "yourusername/smart-im.nvim",
  config = function()
    require("smart-im").setup()
  end,
}
```

### vim-plug

```vim
Plug 'yourusername/smart-im.nvim'

lua << EOF
require("smart-im").setup()
EOF
```

## Prerequisites

### macOS
Install [im-select](https://github.com/daipeihust/im-select):
```bash
brew install im-select
```

### Linux
**IBus**:
```bash
# Usually pre-installed on Ubuntu/Debian
sudo apt install ibus
```

**Fcitx**:
```bash
sudo apt install fcitx
# or for Fcitx5
sudo apt install fcitx5
```

### Windows
Download [im-select.exe](https://github.com/daipeihust/im-select) and add to PATH.

## Configuration

### Default Configuration

```lua
require("smart-im").setup({
  -- Default input method (fallback)
  default_im = "com.apple.keylayout.ABC", -- macOS example
  
  -- Restore previous IM on InsertEnter
  restore_previous = true,
  
  -- Switch to default IM on InsertLeave
  switch_on_leave = true,
  
  -- Filetypes to save IM for (empty = don't track, use default always)
  save_im_for_filetypes = {}, -- e.g., { "markdown", "text" }
  
  -- Events that trigger IM restore
  restore_events = { "InsertEnter" },
  
  -- Events that trigger IM remember and switch to default
  remember_events = { "InsertLeave", "CmdlineLeave" },
  
  -- Custom commands (auto-detected if nil)
  get_im_cmd = nil, -- e.g., "im-select" on macOS
  set_im_cmd = nil, -- e.g., "im-select %s" on macOS
})
```

### Platform-specific Examples

#### macOS
```lua
require("smart-im").setup({
  default_im = "com.apple.keylayout.ABC",
  -- Only remember IM for markdown and text files
  save_im_for_filetypes = { "markdown", "text" },
})
```

#### Linux (IBus)
```lua
require("smart-im").setup({
  default_im = "xkb:us::eng",
})
```

#### Linux (Fcitx)
```lua
require("smart-im").setup({
  default_im = "keyboard-us",
})
```

#### Windows
```lua
require("smart-im").setup({
  default_im = "1033", -- English US
  get_im_cmd = "im-select.exe",
  set_im_cmd = "im-select.exe %s",
})
```

## Usage

### Commands

- `:SmartIMStatus` - Show remembered input methods per filetype
- `:SmartIMClear [filetype]` - Clear memory (all or specific filetype)

### Lua API

```lua
local smart_im = require("smart-im")

-- Set IM for specific filetype
smart_im.set("markdown", "com.apple.inputmethod.SCIM.ITABC")

-- Get current IM
local current = smart_im.get_current_im()

-- Manually remember current IM
smart_im.remember_im()

-- Manually restore IM for current filetype
smart_im.restore_im()

-- Switch to default IM
smart_im.switch_to_default()

-- Clear all memory
smart_im.clear_memory()

-- Clear memory for specific filetype
smart_im.clear_memory("markdown")

-- Get all remembered IMs
local state = smart_im.get_state()
```

## How It Works

1. **InsertLeave**: Remembers the current input method for the buffer's filetype, then switches to default IM
2. **InsertEnter**: Restores the remembered input method for the current filetype (or uses default)
3. **BufLeave**: Remembers IM if leaving buffer while in insert mode

## Example Workflow

With `save_im_for_filetypes = { "markdown", "text" }`:

1. Edit a Markdown file with Chinese input method
2. Leave insert mode → switches to English (default)
3. Open a Lua file, enter insert mode → uses English (default, not tracked)
4. Return to Markdown file and enter insert mode → automatically switches back to Chinese
5. Edit another Lua file → still uses English (Lua is not tracked)

With `save_im_for_filetypes = {}` (track all):

1. Edit any file with any input method
2. The plugin remembers IM for every filetype separately

## Comparison with im-select.nvim

This plugin extends [im-select.nvim](https://github.com/keaising/im-select.nvim) with additional features:

| Feature | smart-im.nvim | im-select.nvim |
|---------|---------------|----------------|
| Per-filetype memory | ✅ | ❌ |
| Auto-detect OS | ✅ | ❌ |
| Lua API | ✅ | Limited |
| User commands | ✅ | ❌ |
| Zero dependencies | ✅ | ✅ |

## Troubleshooting

### Commands not found
Ensure `im-select` (macOS/Windows) or `ibus`/`fcitx-remote` (Linux) is in your PATH:
```bash
which im-select  # macOS
which ibus       # Linux
```

### Wrong default IM
Find your IM identifier:
```bash
# macOS
im-select

# Linux (IBus)
ibus engine

# Linux (Fcitx)
fcitx-remote -n
```

Then set it in config:
```lua
require("smart-im").setup({
  default_im = "your-im-identifier-here",
})
```

## Acknowledgments

This plugin is highly inspired by [im-select.nvim](https://github.com/keaising/im-select.nvim) by [@keaising](https://github.com/keaising).

## Development

### Running Tests

```bash
# Run tests once
make test

# Watch mode (auto-run on file changes)
make test-watch

# Clean test environment
make clean
```

Tests use [lazy.nvim's minitest](https://github.com/folke/lazy.nvim) framework.

## License

MIT

## Contributing

Contributions are welcome! Please follow [Conventional Commits](https://www.conventionalcommits.org/).
