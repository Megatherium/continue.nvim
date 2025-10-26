# Continue.nvim

> **Status**: 🚧 Early Development - Not ready for use yet

AI code assistant for Neovim - a port of the [Continue VSCode extension](https://github.com/continuedev/continue).

## What is Continue?

Continue brings AI-powered development assistance directly into your editor with:

- **💬 Chat** - Ask questions about your code and get contextual answers
- **✏️ Edit** - Modify code inline with natural language instructions
- **⚡ Autocomplete** - AI-powered code suggestions as you type
- **🤖 Agent** - Automated development task execution

## Features (Planned)

- [x] Basic plugin structure
- [ ] Chat interface with LLM integration
- [ ] Inline code editing
- [ ] AI-powered autocomplete
- [ ] Agent task automation
- [ ] Support for multiple AI providers (OpenAI, Anthropic, Ollama)
- [ ] Context-aware code understanding
- [ ] Streaming responses

## Installation

**Note**: This plugin is not yet functional. These are planned installation instructions.

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'your-username/continue.nvim',
  config = function()
    require('continue-nvim').setup({
      provider = {
        name = 'openai',  -- or 'anthropic', 'ollama'
        api_key = os.getenv('OPENAI_API_KEY'),
        model = 'gpt-4',
      },
    })
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'your-username/continue.nvim',
  config = function()
    require('continue-nvim').setup()
  end
}
```

## Configuration

```lua
require('continue-nvim').setup({
  -- AI Provider settings
  provider = {
    name = 'openai',     -- 'openai', 'anthropic', 'ollama'
    api_key = nil,       -- Or set via OPENAI_API_KEY env var
    model = 'gpt-4',     -- Model to use
    api_url = nil,       -- Custom API endpoint (optional)
  },

  -- Enable/disable features
  features = {
    chat = true,
    edit = true,
    autocomplete = true,
    agent = true,
  },

  -- UI settings
  ui = {
    float_border = 'rounded',
    float_width = 0.8,
    float_height = 0.8,
  },

  -- Keybindings (disabled by default)
  keymaps = {
    enabled = false,
    chat = '<leader>cc',
    edit = '<leader>ce',
    agent = '<leader>ca',
  },
})
```

## Usage

### Commands

- `:ContinueChat [message]` - Open chat interface
- `:ContinueEdit` - Start inline edit mode
- `:ContinueAgent [task]` - Start agent for task automation
- `:ContinueConfig` - Show current configuration

### Default Keybindings (when enabled)

- `<leader>cc` - Open Continue chat
- `<leader>ce` - Start Continue edit
- `<leader>ca` - Start Continue agent

## Development Status

This is an early-stage port of the Continue VSCode extension to Neovim. Current progress:

- ✅ Plugin structure and basic setup
- ✅ Configuration system
- ✅ Command registration
- 🚧 LLM integration
- 🚧 Chat interface
- 🚧 Inline editing
- 🚧 Autocomplete
- 🚧 Agent functionality

See [docs/PORTING_CHECKLIST.md](docs/PORTING_CHECKLIST.md) for detailed progress.

## Architecture

Continue.nvim follows a modular architecture:

```
lua/continue-nvim/
├── init.lua              # Main entry point
├── config/               # Configuration
├── chat/                 # Chat interface
├── edit/                 # Inline editing
├── autocomplete/         # AI completions
├── agent/                # Task automation
├── ui/                   # UI components
└── utils/                # Utilities (LLM client, async)
```

## Requirements

- Neovim >= 0.8.0
- curl (for HTTP requests to AI providers)
- Optional: [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) for async operations

## Contributing

This project is in early development. Contributions are welcome once the core architecture is stable.

## License

Apache 2.0 © 2023-2025 Continue Dev, Inc.

Original Continue extension: https://github.com/continuedev/continue

## Related Projects

- [Continue VSCode Extension](https://github.com/continuedev/continue) - The original
- [copilot.vim](https://github.com/github/copilot.vim) - GitHub Copilot for Vim/Neovim
- [codeium.vim](https://github.com/Exafunction/codeium.vim) - Codeium AI for Vim

## Support

- 📖 Documentation: [docs/](docs/)
- 🐛 Issues: GitHub Issues (when ready)
- 💬 Discussions: GitHub Discussions (when ready)
