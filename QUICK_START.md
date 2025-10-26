# Quick Start Guide

Get continue.nvim running in 5 minutes.

## Installation

### 1. Install Continue CLI

```bash
npm install -g @continuedev/cli
```

Verify installation:

```bash
cn --version
```

### 2. Configure Continue (First-Time Setup)

**IMPORTANT**: On first run, you need to manually start `cn` to configure your API key:

```bash
cn
```

This will:
1. Prompt you to select an AI provider (Anthropic, OpenAI, etc.)
2. Ask for your API key
3. Create `~/.continue/config.json` with your settings

After initial setup, the Neovim plugin will auto-start `cn serve` for you.

**Alternative**: Manually create `~/.continue/config.json`:

```json
{
  "models": [
    {
      "title": "Claude",
      "provider": "anthropic",
      "model": "claude-3-5-sonnet-20241022",
      "apiKey": "your-api-key-here"
    }
  ]
}
```

Or set environment variables:

```bash
export ANTHROPIC_API_KEY=your-api-key-here
```

### 3. Install Neovim Plugin

Add to your Neovim config (e.g., `~/.config/nvim/lua/plugins/continue.lua`):

```lua
return {
  'continue.nvim',
  dir = '/path/to/continue.nvim',  -- Local development
  config = function()
    require('continue').setup()
  end,
}
```

Or with lazy.nvim in `init.lua`:

```lua
require("lazy").setup({
  {
    'continue.nvim',
    dir = vim.fn.expand('~/path/to/continue.nvim'),
    config = function()
      require('continue').setup({
        auto_start = true,  -- Start cn serve automatically
      })
    end,
  },
})
```

## First Run

### Start Neovim

```bash
nvim
```

### Run Health Check

```vim
:ContinueHealth
```

Expected output:

```
=== Continue.nvim Health Check ===

✓ Neovim version: 0.10 (OK)
✓ Node.js: v20.x.x
✓ Continue CLI: 0.1.0 (/usr/local/bin/cn)
✓ curl: available

✓ Server: running on port 8000
✓ Server health: OK
```

### Open Chat

```vim
:Continue
```

You should see a floating window with:

```
╔══════════════════════════════════════════════════════════╗
║                  Continue.nvim Chat                      ║
╚══════════════════════════════════════════════════════════╝

Waiting for messages...

Use :Continue <message> to send a message
Press q or <Esc> to close this window
```

### Send a Message

```vim
:Continue Write a hello world in Rust
```

Watch the chat window for the streaming response!

## Troubleshooting

### Server not starting

```vim
:ContinueStart
:messages  " Check for errors
```

### Check server status

```vim
:ContinueStatus
```

### Manually test server

In a terminal:

```bash
cn serve --port 8000
```

Then in Neovim:

```vim
:Continue test message
```

### View logs

The `cn serve` output will show in the terminal where it was started. Look for errors there.

### Common Issues

**"cn not found"**
- Make sure `npm install -g @continuedev/cli` succeeded
- Check `which cn` in your terminal
- Verify `$PATH` includes npm global bin directory

**"No API key configured"**
- Set up `~/.continue/config.json` with your API key
- Or set environment variable: `export ANTHROPIC_API_KEY=...`

**"curl not found"**
- Install curl: `apt install curl` or `brew install curl`

**"Neovim version too old"**
- Upgrade to Neovim 0.10+: https://github.com/neovim/neovim/releases

## Testing the Plugin

### Run Integration Tests

```bash
# Start server first
cn serve --port 8000

# In another terminal, start Neovim
nvim

# Run tests
:luafile tests/test_http_client.lua
```

Expected output:

```
============================================================
Testing JSON Utils
============================================================
✓ JSON encode success
✓ JSON encode contains key
✓ JSON decode success
...

============================================================
Test Results
============================================================
ℹ Tests run: 23
✓ Passed: 23
ℹ Success rate: 100%

🎉 All tests passed!
```

## Next Steps

- Try more complex prompts: `:Continue Refactor this function to use async/await`
- Use git integration: `:ContinueDiff` to show changes
- Explore chat window: `:Continue` then watch it update in real-time
- Check status: `:ContinueStatus` to see server info

## Commands Reference

| Command | Description |
|---------|-------------|
| `:Continue [msg]` | Open chat or send message |
| `:ContinueStart` | Start cn serve |
| `:ContinueStop` | Stop cn serve |
| `:ContinuePause` | Interrupt agent |
| `:ContinueStatus` | Show status |
| `:ContinueDiff` | Show git diff |
| `:ContinueHealth` | Health check |

## Configuration Options

```lua
require('continue').setup({
  port = 8000,              -- Default port
  port_range = { 8000, 8010 }, -- Port scan range
  timeout = 300,            -- Server timeout (seconds)
  auto_start = true,        -- Auto-start on load
  auto_find_port = true,    -- Auto-find available port
  cn_bin = 'cn',            -- Path to cn binary
  continue_config = nil,    -- Custom config path
})
```

---

**Need help?** Check `IMPLEMENTATION_SUMMARY.md` for detailed notes or open an issue.