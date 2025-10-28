# Continue.nvim

> **Status**: 🚧 Phase 1 Complete - HTTP Client & Core UI Implemented

AI code assistant for Neovim - a **lightweight HTTP client** for [Continue CLI](https://github.com/continuedev/continue).

## Architecture: HTTP Client Approach

Instead of porting the entire Continue codebase (40-70K tokens of TypeScript), continue.nvim is a **thin HTTP client** that connects to `cn serve` (the Continue CLI backend).

**Benefits:**
- 🚀 **90% less code** - Only ~5K tokens of Lua
- 🔄 **Always up-to-date** - `npm update @continuedev/cli` gets latest features
- 🎯 **Same behavior** - Identical to Continue CLI (no divergence)
- 🛠️ **All features** - Agent, Chat, Tools, MCP - everything Continue offers

## Features

### Core Features ✅

**HTTP Client & Infrastructure:**
- [x] **HTTP Client** - curl-based async requests with timeout handling
- [x] **Process Manager** - Auto-start/stop `cn serve` with port scanning
- [x] **State Polling** - Dynamic intervals (100ms active, 1s idle)
- [x] **Chat UI** - Split window with input area (80% chat, 20% input)
- [x] **Message Formatting** - User/Assistant/System/Tool messages
- [x] **Streaming Support** - Character-by-character real-time updates
- [x] **Permission System** - Interactive tool approval prompts
- [x] **State Diffing** - Efficient UI updates (only render changes)

**Polish & UX:**
- [x] **Syntax Highlighting** - Code blocks with language-aware highlighting
- [x] **Message Copying** - yy (current), yA (all) to clipboard
- [x] **Keyboard Help** - Press ? for interactive help
- [x] **Processing Indicator** - Real-time status (⏳/📥/✅) in header
- [x] **Request Retry** - Auto-retry transient failures (2x max)
- [x] **Welcome Screen** - Beautiful ASCII art and quick start
- [x] **Export to Markdown** - :ContinueExport command

### Advanced Features ✨ (New!)

**Autocomplete Systems:**
- [x] **Slash Command Autocomplete** - Fuzzy-finding preview for /commands
  - Real-time filtering as you type
  - Keyboard navigation (↑/↓, Tab)
  - 16 system commands + custom commands support
  - Visual indicators (⚙ system, 🤖 custom)
  
- [x] **File Attachment Picker** - Git-aware fuzzy finder for @mentions
  - Fuzzy matching on filenames and paths
  - Multi-select support (attach multiple files)
  - Keyboard navigation (↑/↓, Tab)
  - Visual indicators for attached files

**Search & Navigation:**
- [x] **Vim-Style Search** - Search chat history with /, n, N
  - Real-time search with match highlighting
  - Jump between matches (n/N)
  - Match counter (e.g., "Match 3 of 12")
  - Clear highlights with <C-l>

- [x] **Code Block Navigation** - Jump between code blocks
  - ]c / [c to navigate blocks
  - Language detection from fences

**Code Operations:**
- [x] **Code Block Extraction** - One-key operations on code blocks
  - yc to yank (copy) code block at cursor
  - ]c / [c to jump between blocks
  - <leader>ce to execute (Lua, Vim, Bash, Python)
  - <leader>cw to write block to file

**Enhanced UI:**
- [x] **Help Overlay** - Comprehensive keyboard reference (g?)
  - Full-screen help with all keybindings
  - Syntax-highlighted sections
  - Tips & tricks
  - Architecture overview

- [x] **Local Command Handlers** - Instant execution of common commands
  - /clear - Clear history (with confirmation)
  - /help - Show help overlay
  - /exit - Close chat window

**Commands:**
- [x] `:Continue [msg]` - Open chat or send message
- [x] `:ContinueStart/Stop` - Server management
- [x] `:ContinuePause` - Interrupt agent
- [x] `:ContinueStatus` - Show status
- [x] `:ContinueDiff` - Show git diff
- [x] `:ContinueHealth` - Dependency check
- [x] `:ContinueExport [file]` - Export to markdown

### Future Enhancements 📋

- [ ] Treesitter integration (enhanced syntax highlighting)
- [ ] Session persistence (save/restore across restarts)
- [ ] Visual mode operations (send selection)
- [ ] Mode indicators (normal/plan/auto from CLI)
- [ ] Custom command loading from server

## Installation

### Prerequisites

- **Neovim 0.10+** (for `vim.json` built-in)
- **Node.js 18+** (for Continue CLI)
- **curl** (for HTTP requests)

### Step 1: Install Continue CLI

```bash
npm install -g @continuedev/cli
```

### Step 1.5: First-time Setup

```bash
cn init
```

### Step 2: Install Plugin

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'continue.nvim',
  dev = true,  -- For local development
  config = function()
    require('continue').setup({
      port = 8000,              -- Default port for cn serve
      port_range = { 8000, 8010 }, -- Auto-find available port
      timeout = 300,            -- Server timeout (seconds)
      auto_start = false,       -- DEPRECATED: server starts lazily on first command
      auto_find_port = true,    -- Find available port automatically
      cn_bin = 'cn',            -- Path to cn binary
      continue_config = nil,    -- Path to Continue config (optional)
    })
  end,
}
```

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  'continue.nvim',
  config = function()
    require('continue').setup()
  end
}
```

## Configuration

All configuration options with defaults:

```lua
require('continue').setup({
  port = 8000,              -- Default port for cn serve
  port_range = { 8000, 8010 }, -- Range for auto port finding
  timeout = 300,            -- Server auto-shutdown timeout (seconds)
  auto_start = false,       -- DEPRECATED: server now starts lazily on first command
  auto_find_port = true,    -- Automatically find available port
  cn_bin = 'cn',            -- Path to cn CLI binary
  continue_config = nil,    -- Custom Continue config path (optional)
  
  -- Terminal window configuration
  terminal = {
    position = 'float',    -- 'float', 'left', 'right', 'top', 'bottom'
    hsize = 80,            -- Horizontal size in % (for float/left/right)
    vsize = 80,            -- Vertical size in % (for float/top/bottom)
    transparency = 0,      -- Transparency 0-100 (only for float, requires nvim 0.9+)
  },
})
```

### Terminal Window Positions

- **`float`** (default): Centered floating window with configurable transparency
- **`left`**: Vertical split on the left side
- **`right`**: Vertical split on the right side
- **`top`**: Horizontal split at the top
- **`bottom`**: Horizontal split at the bottom

**Note**: AI provider configuration (API keys, models) is handled by Continue CLI, not this plugin. Configure via `~/.continue/config.json` or environment variables. See [Continue docs](https://docs.continue.dev).

## Usage

### Quick Start

```vim
" Open chat window
:Continue

" Send a message directly
:Continue How do I implement a binary search in Rust?

" Check health status
:ContinueHealth
```

### Commands

| Command | Description |
|---------|-------------|
| `:Continue [message]` | Open chat or send message directly (auto-starts server) |
| `:ContinueStart` | Manually start `cn serve` if needed |
| `:ContinueStop` | Stop server and polling |
| `:ContinuePause` | Interrupt current agent execution (like Ctrl+C) |
| `:ContinueStatus` | Show server and client status |
| `:ContinueDiff` | Show git diff in split window |
| `:ContinueHealth` | Run health check (dependencies + server) |

### Keymaps (in Chat Window)

| Key | Action |
|-----|--------|
| `q` or `<Esc>` | Close chat window |
| `g?` | Show comprehensive help overlay |
| `yy` | Copy current message to clipboard |
| `yA` | Copy all messages to clipboard |
| `/` | Search in chat history (vim-style) |
| `n` | Jump to next search match |
| `N` | Jump to previous search match |
| `<C-l>` | Clear search highlights |

**Code Block Operations:**

| Key | Action |
|-----|--------|
| `yc` | Yank (copy) code block at cursor |
| `]c` | Jump to next code block |
| `[c` | Jump to previous code block |
| `<leader>ce` | Execute code block (Lua/Vim/Bash/Python) |
| `<leader>cw` | Write code block to file |

**Input Area:**

| Key | Action |
|-----|--------|
| `i` or `a` | Start typing (insert mode) |
| `<CR>` | Send message |
| `/command` | Trigger slash command autocomplete |
| `@filename` | Trigger file picker autocomplete |
| `↑` / `↓` | Navigate autocomplete suggestions |
| `Tab` | Complete/select suggestion |
| `<Esc>` | Cancel/hide suggestions |

**Window Resizing:**

| Key | Action |
|-----|--------|
| `<C-w>+` | Increase window height |
| `<C-w>-` | Decrease window height |
| `<C-w>>` | Increase window width |
| `<C-w><` | Decrease window width |
| `<C-w>=` | Reset window to default size |

**Note**: Resize keybindings work in both floating and split window modes.

## Testing

### Manual Testing

Start Continue server:

```bash
cn serve --port 8000
```

Run integration tests in Neovim:

```vim
:luafile tests/test_http_client.lua
```

### Health Check

```vim
:ContinueHealth
```

Example output:

```
=== Continue.nvim Health Check ===

✓ Neovim version: 0.10 (OK)
✓ Node.js: v20.11.0
✓ Continue CLI: 0.1.0 (/usr/local/bin/cn)
✓ curl: available

✓ Server: running on port 8000
✓ Server health: OK
```

## Architecture

```
┌─────────────────────────────────┐
│         Neovim                  │
│  ┌──────────────────────────┐   │
│  │  continue.nvim           │   │
│  │  (Lua - ~8K tokens)      │   │
│  │                          │   │  HTTP/JSON
│  │  • HTTP client           │───┼────────┐
│  │  • State polling         │   │        │
│  │  • UI rendering          │   │        │
│  │  • Commands              │   │        │
│  └──────────────────────────┘   │        │
└─────────────────────────────────┘        │
                                           ▼
                                     ┌─────────────────┐
                                     │   cn serve      │
                                     │  (Node.js/TS)   │
                                     │                 │
                                     │  • Agent logic  │
                                     │  • LLM APIs     │
                                     │  • Tools/MCP    │
                                     │  • All Continue │
                                     │    features     │
                                     └─────────────────┘
```

### Project Structure

```
lua/continue/
├── init.lua          # Entry point & setup()
├── client.lua        # HTTP client (endpoints, polling)
├── process.lua       # cn serve lifecycle management
├── commands.lua      # User commands (:Continue, etc.)
├── ui/
│   └── chat.lua      # Chat window & message rendering
└── utils/
    ├── http.lua      # curl wrapper (async HTTP)
    └── json.lua      # vim.json wrapper

tests/
└── test_http_client.lua  # Integration tests
```

### HTTP Protocol

The plugin communicates with `cn serve` via REST API:

- `GET /state` - Poll for chat state (every 500ms)
- `POST /message` - Send user message
- `POST /permission` - Approve/reject tool execution
- `POST /pause` - Interrupt agent
- `GET /diff` - Get git diff
- `POST /exit` - Graceful shutdown

See [source/extensions/cli/spec/wire-format.md](source/extensions/cli/spec/wire-format.md) for full protocol spec.

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