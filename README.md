# smart-im.nvim

Smart input method switcher for Neovim with per-buffer memory.

> Highly inspired by [im-select.nvim](https://github.com/keaising/im-select.nvim)

## Features

- 🎯 **Per-buffer Memory**: Automatically remembers the last used input method for each buffer
- 🔄 **Mode-aware**: Tracks IM changes on insert↔normal and terminal↔normal transitions
- 🌍 **Cross-platform**: Works on macOS, Linux (IBus/Fcitx), and Windows
- ⚡ **Lightweight**: Zero dependencies, pure Lua implementation
- 🧹 **Memory Efficient**: Auto-cleanup on buffer delete, skips storing default IM
- 🔧 **Customizable**: Lua API for manual control

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

- Neovim 0.9.0 or newer

### macOS
Install [im-select](https://github.com/daipeihust/im-select) or [macism](https://github.com/laishulu/macism):
```bash
brew install im-select
# or
brew install macism
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
  -- Default input method (used in normal mode)
  default_im = "com.apple.keylayout.US", -- macOS example

  -- Enable debug logging
  debug = false,

  -- Custom commands (auto-detected if nil)
  get_im_cmd = nil, -- e.g., "macism" or "im-select" on macOS
  set_im_cmd = nil, -- e.g., "macism %s" on macOS
})
```

### Platform-specific Examples

#### macOS (with macism)
```lua
require("smart-im").setup({
  default_im = "com.apple.keylayout.US",
  get_im_cmd = "macism",
  set_im_cmd = "macism %s",
})
```

#### macOS (with im-select)
```lua
require("smart-im").setup({
  default_im = "com.apple.keylayout.ABC",
  get_im_cmd = "im-select",
  set_im_cmd = "im-select %s",
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

- `:SmartIMStatus` - Show remembered input methods per buffer
- `:SmartIMClear` - Clear all remembered input methods

### Lua API

```lua
local im = require("smart-im.im")

-- Manually remember current IM for current buffer
im.remember()

-- Manually restore IM for current buffer
im.restore()

-- Get current IM
local current_im = require("smart-im.utils").get_current_im()
```

## How It Works

The plugin uses `ModeChanged` autocmd to track mode transitions:

1. **insert → normal** (`i:n`): Captures current IM before macOS auto-switches, saves it for the buffer
2. **normal → insert** (`n:i`): Restores saved IM for the buffer (or default if none saved)
3. **terminal → normal** (`t:nt`): Captures current IM for terminal buffer
4. **normal → terminal** (`nt:t`): Restores saved IM for terminal buffer
5. **BufDelete**: Cleans up saved IM data to prevent memory leaks

## Example Workflow

1. Open `README.md` in insert mode → uses default English
2. Switch to Chinese, type some text, return to normal mode → remembers Chinese for this buffer
3. Open `main.lua` in insert mode → uses default English (different buffer)
4. Switch to Japanese, return to normal mode → remembers Japanese for this buffer
5. Return to `README.md` insert mode → automatically switches to Chinese
6. Open terminal → remembers its own IM separately from text buffers

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
