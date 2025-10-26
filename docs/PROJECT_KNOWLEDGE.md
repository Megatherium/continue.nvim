# Project Knowledge Base

## Architecture Overview

### Current Status
- **Phase**: Architecture design & HTTP client implementation
- **Approach**: Thin Neovim client → `cn serve` HTTP backend
- **Target**: Neovim plugin (Lua)
- **Backend**: Continue CLI (`@continuedev/cli`)
- **Primary Language**: Lua 5.1/LuaJIT

### Design Decisions

#### Architecture Choice

**Decision**: Build HTTP client for `cn serve` instead of porting TypeScript

**Rationale:**
- **Reuse 100%** of Continue's logic (agent, LLM, tools, MCP)
- **90% less code**: 5-10K tokens vs 40-70K tokens
- **Auto-updates**: `npm update @continuedev/cli` gets new features
- **Same behavior**: Identical to Continue CLI
- **Simpler maintenance**: No TypeScript tracking needed
- **Clear separation**: Neovim UI ↔ Continue backend

### Architecture Diagram

```
┌──────────────────────────────────────────┐
│  Neovim (continue.nvim Lua plugin)       │
│  ┌────────────────────────────────────┐  │
│  │  UI Layer                          │  │
│  │  • Chat buffer                     │  │
│  │  • Floating windows                │  │
│  │  • Syntax highlighting             │  │
│  └──────────────┬─────────────────────┘  │
│                 │                         │
│  ┌──────────────▼─────────────────────┐  │
│  │  HTTP Client (client.lua)          │  │
│  │  • GET /state (poll 500ms)         │  │
│  │  • POST /message                   │  │
│  │  • POST /permission                │  │
│  │  • POST /pause                     │  │
│  └──────────────┬─────────────────────┘  │
│                 │ vim.loop HTTP          │
│  ┌──────────────▼─────────────────────┐  │
│  │  Process Manager (process.lua)     │  │
│  │  • jobstart('cn serve')            │  │
│  │  • Health checks                   │  │
│  │  • Graceful shutdown               │  │
│  └──────────────┬─────────────────────┘  │
└─────────────────┼───────────────────────┘
                  │ HTTP :8000
                  ▼
    ┌──────────────────────────────────┐
    │  cn serve (Node.js/TypeScript)   │
    │  ┌────────────────────────────┐  │
    │  │  Continue CLI Backend      │  │
    │  │  • Agent loop              │  │
    │  │  • LLM API clients         │  │
    │  │  • Tool execution          │  │
    │  │  • MCP servers             │  │
    │  │  • Session management      │  │
    │  │  • Permission system       │  │
    │  └────────────────────────────┘  │
    └──────────────────────────────────┘
```

#### Technology Stack

```
Neovim Plugin (Lua Client)
├── Lua 5.1/LuaJIT (Neovim embedded)
├── Neovim API 0.10+ (nvim_*)
├── vim.loop (libuv) for HTTP & timers
└── vim.json for JSON parsing (built-in)

Backend (Continue CLI - External)
├── Node.js 18+
├── @continuedev/cli package
└── All Continue features

Communication
├── HTTP REST API (localhost:8000)
├── JSON payloads
└── Polling-based (500ms intervals)
```

#### Plugin Structure

```
lua/continue/
├── init.lua              # Entry point, setup()
├── config.lua            # Configuration schema
├── process.lua           # cn serve lifecycle
├── client.lua            # HTTP client
├── commands.lua          # Neovim commands
├── ui/
│   ├── chat.lua          # Chat buffer UI
│   ├── floating.lua      # Floating windows
│   └── render.lua        # Message rendering
└── utils/
    ├── http.lua          # HTTP helpers
    └── json.lua          # JSON encode/decode
```

## HTTP Protocol Reference

Based on `source/extensions/cli/spec/wire-format.md`

### Endpoints

#### `GET /state`
**Purpose**: Get current agent state (poll every 500ms)

**Response**:
```json
{
  "chatHistory": [
    {
      "role": "user" | "assistant" | "system",
      "content": "string",
      "isStreaming": boolean,
      "messageType": "tool-start" | "tool-result" | "tool-error" | "system",
      "toolName": "string",
      "toolResult": "string"
    }
  ],
  "isProcessing": boolean,
  "messageQueueLength": number,
  "pendingPermission": {
    "requestId": "string",
    "toolName": "string",
    "args": "object"
  } | null
}
```

**Implementation**:
```lua
-- Poll every 500ms with vim.loop timer
local timer = vim.loop.new_timer()
timer:start(0, 500, vim.schedule_wrap(function()
  http.get('http://localhost:8000/state', function(state)
    -- Update UI with new state
    ui.update(state)
  end)
end))
```

#### `POST /message`
**Purpose**: Send user message to agent

**Request**:
```json
{
  "message": "string"
}
```

**Response**:
```json
{
  "queued": true,
  "position": number
}
```

**Implementation**:
```lua
function send_message(text)
  http.post('http://localhost:8000/message', {
    message = text
  }, function(response)
    vim.notify('Message queued at position ' .. response.position)
  end)
end
```

#### `POST /permission`
**Purpose**: Approve/reject tool execution

**Request**:
```json
{
  "requestId": "string",
  "approved": boolean
}
```

**Usage**: When `state.pendingPermission` exists, prompt user and send response

#### `POST /pause`
**Purpose**: Interrupt current agent execution

**Usage**: Mapped to keymap (like `<Esc>` in chat window)

#### `GET /diff`
**Purpose**: Get git diff from working tree

**Response**:
```json
{
  "diff": "string"
}
```

#### `POST /exit`
**Purpose**: Gracefully shutdown `cn serve`

**Usage**: Called on `:ContinueStop` or `VimLeavePre`

### Protocol Flow

1. **Startup**:
   - Spawn `cn serve --port 8000`
   - Wait for health check (`GET /state` returns 200)
   - Start polling timer

2. **User sends message**:
   - User types in chat buffer
   - `POST /message` with content
   - Continue polling to see updates

3. **Streaming response**:
   - Poll detects `isStreaming: true`
   - Update UI incrementally as `content` grows
   - Stop when `isStreaming: false`

4. **Tool permission**:
   - Poll detects `pendingPermission`
   - Show prompt to user
   - `POST /permission` with approval

5. **Shutdown**:
   - `POST /exit` to server
   - Wait for graceful shutdown
   - Kill process if timeout

---

## Process Management

### Spawning cn serve

```lua
local M = {}
local state = {
  job_id = nil,
  port = 8000,
  running = false
}

function M.start(opts)
  opts = opts or {}
  local port = opts.port or 8000
  
  local cmd = { 'cn', 'serve', '--port', tostring(port) }
  
  state.job_id = vim.fn.jobstart(cmd, {
    on_stdout = function(_, data)
      -- Log output
      for _, line in ipairs(data) do
        if line ~= '' then
          vim.notify('[cn serve] ' .. line, vim.log.levels.INFO)
        end
      end
    end,
    on_stderr = function(_, data)
      -- Log errors
      for _, line in ipairs(data) do
        if line ~= '' then
          vim.notify('[cn serve ERROR] ' .. line, vim.log.levels.ERROR)
        end
      end
    end,
    on_exit = function(_, code)
      state.running = false
      state.job_id = nil
      if code ~= 0 then
        vim.notify('cn serve exited with code ' .. code, vim.log.levels.ERROR)
      end
    end,
  })
  
  if state.job_id <= 0 then
    vim.notify('Failed to start cn serve', vim.log.levels.ERROR)
    return false
  end
  
  state.port = port
  state.running = true
  
  -- Wait for server to be ready
  M.wait_for_ready(5000)  -- 5 second timeout
  
  return true
end

function M.wait_for_ready(timeout_ms)
  local start = vim.loop.now()
  local timer = vim.loop.new_timer()
  
  timer:start(100, 100, vim.schedule_wrap(function()
    -- Health check
    http.get('http://localhost:' .. state.port .. '/state', function(response)
      if response then
        timer:stop()
        timer:close()
        vim.notify('cn serve ready', vim.log.levels.INFO)
      elseif vim.loop.now() - start > timeout_ms then
        timer:stop()
        timer:close()
        M.stop()
        vim.notify('cn serve failed to start', vim.log.levels.ERROR)
      end
    end)
  end))
end

function M.stop()
  if state.job_id then
    -- Try graceful shutdown first
    http.post('http://localhost:' .. state.port .. '/exit', {}, function()
      -- Give it 2 seconds to exit
      vim.defer_fn(function()
        if state.job_id then
          vim.fn.jobstop(state.job_id)
        end
      end, 2000)
    end)
  end
end

-- Auto-cleanup on Neovim exit
vim.api.nvim_create_autocmd('VimLeavePre', {
  callback = function()
    M.stop()
  end,
})

return M
```

### Health Checks

```lua
function M.health_check()
  if not state.running then
    return { status = 'stopped' }
  end
  
  -- Quick ping
  http.get('http://localhost:' .. state.port .. '/state', function(response)
    if response then
      return { status = 'running', port = state.port }
    else
      return { status = 'error', message = 'Server not responding' }
    end
  end)
end
```

---

## Pain Points & Gotchas

### Neovim/Lua-Specific

**Lua 5.1 Limitations**
- Issue: Old Lua version, no bitwise operators (until LuaJIT), limited stdlib
- Solution: Use `bit` library for bitwise ops, vendor needed utilities
- Watch out for: No `continue` keyword (use goto or inverse conditions)

**Global Namespace Pollution**
- Issue: All requires are cached globally, easy to conflict
- Solution: Always namespace your plugin: `require('your-plugin.module')`
```lua
-- Bad
M = {}
function do_thing() end

-- Good
local M = {}
function M.do_thing() end
return M
```

**Async Patterns**
- Issue: Neovim API is mostly callback-based, no async/await
- Solution: Use plenary's async lib or write callback hell
```lua
-- Callback style (native)
vim.loop.fs_open(path, "r", 438, function(err, fd)
  vim.loop.fs_read(fd, size, offset, function(err, data)
    -- nested callbacks...
  end)
end)

-- With plenary.async
local async = require('plenary.async')
async.run(function()
  local fd = async.uv.fs_open(path, "r", 438)
  local data = async.uv.fs_read(fd, size, offset)
end)
```

**Buffer/Window Lifecycle**
- Issue: Buffer/window IDs become invalid when closed
- Solution: Always validate with `vim.api.nvim_buf_is_valid()`
```lua
local bufnr = vim.api.nvim_create_buf(false, true)
-- Later...
if vim.api.nvim_buf_is_valid(bufnr) then
  -- safe to use
end
```

**Autocommand Memory Management**
- Issue: Autocommands don't auto-cleanup, causes leaks/duplicates
- Solution: Use augroups and clear them
```lua
local augroup = vim.api.nvim_create_augroup('PluginName', { clear = true })
vim.api.nvim_create_autocmd('BufEnter', {
  group = augroup,
  pattern = '*.lua',
  callback = function() end,
})
```

**API vs Vimscript**
- Issue: Some things still require Vimscript (e.g., complex :substitute)
- Solution: Use `vim.cmd()` or `vim.fn.*()` for legacy operations
```lua
-- Execute Vimscript
vim.cmd('silent! %s/foo/bar/g')

-- Call Vimscript function
local result = vim.fn.input('Prompt: ')
```

**Error Handling**
- Issue: `pcall` returns (status, result_or_error), easy to misuse
- Solution: Always check status first
```lua
local ok, result = pcall(risky_function, args)
if not ok then
  vim.notify('Error: ' .. tostring(result), vim.log.levels.ERROR)
  return
end
-- use result safely
```

**UI Limitations**
- Issue: No native rich UI like VSCode WebViews
- Solution: Floating windows + creative buffer manipulation
- Advanced: Use nui.nvim or integrate with external tools

**Module Reloading (Development)**
- Issue: `require()` caches modules, changes need restart
- Solution: Use plenary's reload or clear package.loaded
```lua
-- For development
package.loaded['your-plugin.module'] = nil
require('your-plugin.module')
```

### Porting-Specific Gotchas

**From TypeScript/JavaScript**
- No classes (use tables with metatables if needed)
- No promises (use callbacks or plenary.async)
- Arrays are 1-indexed, not 0-indexed (!)
- `undefined` vs `null` → Lua only has `nil`
- No object destructuring (manual extraction)

**From Kotlin/Java**
- No static typing (use EmmyLua annotations for LSP hints)
- No exceptions (use pcall/error patterns)
- No threading (single-threaded event loop)
- No method overloading (use optional params with defaults)

### VSCode-Specific (If Porting From)

**Activation Events → Autocommands**
```typescript
// VSCode
"activationEvents": ["onLanguage:python"]

-- Neovim
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'python',
  callback = function() require('plugin').setup() end,
})
```

**Disposables → Manual Cleanup**
- VSCode: context.subscriptions auto-cleanup
- Neovim: Must manually unbind/delete resources

**Configuration**
```typescript
// VSCode
vscode.workspace.getConfiguration('myPlugin').get('setting')

-- Neovim (option 1: vim.g)
vim.g.my_plugin_setting

-- Neovim (option 2: lua module)
require('my-plugin').config.setting
```

### JetBrains-Specific (If Porting From)

**PSI → Tree-sitter**
- PSI: Abstract syntax tree with full type information
- Tree-sitter: Concrete syntax tree, no semantic info
- You'll lose type-aware refactoring capabilities

**Threading → Single Thread**
- JetBrains: Explicit read/write actions, background tasks
- Neovim: Everything on main thread, use vim.schedule for deferred work
```lua
-- Run something after current execution
vim.schedule(function()
  -- This runs on next event loop iteration
end)
```

**Actions → Commands + Keymaps**
```kotlin
// JetBrains: Unified action with keymap XML
class MyAction : AnAction() { }

-- Neovim: Separate command and mapping
vim.api.nvim_create_user_command('MyAction', function()
  -- implementation
end, {})

vim.keymap.set('n', '<leader>ma', ':MyAction<CR>', { desc = 'My Action' })
```

---

## TODOs & Roadmap

### Phase 0: Analysis (Current)
- [x] Determine target platform (Neovim)
- [ ] Analyze both source plugins (feature inventory)
- [ ] Choose source plugin (VSCode vs JetBrains)
- [ ] Identify Neovim API gaps/workarounds needed
- [ ] Document business logic that's platform-agnostic

### Phase 1: Foundation (Days 1-2)
- [ ] Set up Neovim plugin structure
- [ ] Create minimal plugin skeleton
- [ ] Set up development environment (hot reload)
- [ ] Test basic command registration

### Phase 2: Core Logic Port (Days 3-5)
- [ ] Extract and port business logic (language-agnostic parts)
- [ ] Implement Neovim API adapters
- [ ] Port configuration system
- [ ] Basic error handling

### Phase 3: Feature Parity (Days 6-8)
- [ ] Port all commands
- [ ] Port all keybindings
- [ ] Port UI elements (as floating windows/popups)
- [ ] Implement autocommands for reactive behavior

### Phase 4: Polish (Days 9-10)
- [ ] Performance optimization
- [ ] Write Vim help docs (`:help plugin-name`)
- [ ] Add user configuration examples
- [ ] Integration testing

### Phase 5: Release
- [ ] Create README with installation instructions
- [ ] Submit to package managers (lazy.nvim, packer, etc.)
- [ ] Announce to Neovim community

---

## Development Guidelines

### For Humans

**Quick Start**
```bash
# Clone your plugin to Neovim config
mkdir -p ~/.config/nvim/lua
ln -s $(pwd)/lua/your-plugin ~/.config/nvim/lua/your-plugin

# Or use lazy.nvim (recommended)
# In ~/.config/nvim/lua/plugins/your-plugin.lua
return {
  'your-github-user/your-plugin.nvim',
  dir = '~/projects/your-plugin',  -- for local dev
  config = function()
    require('your-plugin').setup({})
  end,
}
```

**Hot Reload During Development**
```vim
" Reload plugin code without restarting Neovim
:lua package.loaded['your-plugin'] = nil
:lua require('your-plugin').setup()

" Or create a command
:command! PluginReload lua package.loaded['your-plugin'] = nil; require('your-plugin').setup()
```

**Debugging**
```lua
-- Print debugging
print(vim.inspect(complex_table))

-- Notify debugging (visible)
vim.notify('Debug: ' .. vim.inspect(value), vim.log.levels.DEBUG)

-- Log to file
local log_file = io.open('/tmp/plugin-debug.log', 'a')
log_file:write(vim.inspect(data) .. '\n')
log_file:close()
```

**Testing**
```bash
# Using plenary.nvim test framework
nvim --headless -c "PlenaryBustedDirectory lua/tests/ {minimal_init = 'tests/minimal_init.lua'}"
```

### For LLMs

**Context You Need**
1. Read PROJECT_KNOWLEDGE.md (this file) first
2. If porting from VSCode: Check `package.json` for commands/config
3. If porting from JetBrains: Check `plugin.xml` and action registration
4. Read source plugin's README for feature overview
5. Check `lua/your-plugin/init.lua` for current Neovim implementation

**Common Patterns to Look For**

When analyzing source plugin:
- Command definitions (these map to user commands in Neovim)
- Configuration schema (these become lua table fields)
- Event handlers (these become autocommands)
- UI interactions (these need creative solutions in Neovim)
- Async operations (need callback conversion or plenary.async)

**Porting Strategy**

1. **Inventory Phase**: List all features/commands from source
2. **API Mapping**: Document source API → Neovim API equivalents
3. **Core Logic**: Extract business logic (should be platform-agnostic)
4. **Adapters**: Write thin adapters for Neovim APIs
5. **Test**: Build incrementally, test each command as you port

**Code Organization Pattern**
```lua
-- lua/your-plugin/init.lua
local M = {}

M.config = {
  -- default configuration
  default_setting = true,
}

function M.setup(user_config)
  M.config = vim.tbl_deep_extend('force', M.config, user_config or {})
  require('your-plugin.commands').setup()
  require('your-plugin.autocmds').setup()
end

return M
```

**Token Budget Awareness**
- Lua is concise; use it to your advantage
- Don't translate comments verbatim (Lua culture prefers code clarity)
- When porting TypeScript → Lua, you'll often reduce LOC by 30-40%
- When porting Kotlin → Lua, you'll reduce LOC by 50-60% (less boilerplate)
- Use `str_replace` for targeted edits
- For new files, create complete but minimal implementations

**Neovim-Specific Best Practices**
```lua
-- Use local variables everywhere
local M = {}
local internal_state = {}

-- Provide clear setup function
function M.setup(opts)
  opts = opts or {}
  -- merge with defaults
end

-- Export only what's needed
return M

-- Use descriptive command names
vim.api.nvim_create_user_command('PluginActionName', fn, {
  desc = 'Clear description for :Telescope commands'
})

-- Provide default keymaps as opt-in
if config.default_keymaps then
  vim.keymap.set('n', '<leader>xx', function() end, { desc = 'Action' })
end
```

---

## API Quick Reference

### Neovim API Essentials

```lua
-- ============================================
-- BUFFERS & WINDOWS
-- ============================================

-- Get current buffer/window
local bufnr = vim.api.nvim_get_current_buf()
local winnr = vim.api.nvim_get_current_win()

-- Create buffer
local bufnr = vim.api.nvim_create_buf(
  false,  -- listed (show in buffer list)
  true    -- scratch (no file, deleted when hidden)
)

-- Buffer operations
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {'line1', 'line2'})
local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
vim.api.nvim_buf_set_name(bufnr, 'name')
vim.api.nvim_buf_is_valid(bufnr)

-- Window operations
vim.api.nvim_open_win(bufnr, true, {
  relative = 'editor',
  width = 80,
  height = 20,
  row = 5,
  col = 5,
  style = 'minimal',
  border = 'rounded',
})

-- ============================================
-- COMMANDS & KEYMAPS
-- ============================================

-- Create user command
vim.api.nvim_create_user_command('CommandName', function(opts)
  -- opts.args = arguments as string
  -- opts.fargs = arguments as table
  -- opts.bang = ! was used
  print('Command executed with args:', opts.args)
end, {
  nargs = '*',      -- 0, 1, *, +, ?
  bang = true,      -- allow !
  desc = 'Description for :Telescope commands',
  complete = 'file',  -- completion type
})

-- Delete user command
vim.api.nvim_del_user_command('CommandName')

-- Set keymap
vim.keymap.set('n', '<leader>xx', function()
  print('Keymap triggered')
end, {
  desc = 'Description',
  buffer = bufnr,  -- buffer-local, or nil for global
  silent = true,
  noremap = true,
})

-- ============================================
-- AUTOCOMMANDS
-- ============================================

-- Create augroup (namespace for autocommands)
local augroup = vim.api.nvim_create_augroup('PluginName', { clear = true })

-- Create autocommand
vim.api.nvim_create_autocmd({'BufEnter', 'BufWritePost'}, {
  group = augroup,
  pattern = '*.lua',  -- or {'*.lua', '*.vim'}
  callback = function(args)
    -- args.buf = buffer number
    -- args.file = filename
    -- args.match = matched pattern
    print('Autocommand triggered')
  end,
  desc = 'Description',
})

-- One-time autocommand
vim.api.nvim_create_autocmd('VimEnter', {
  once = true,
  callback = function() print('Runs once') end,
})

-- ============================================
-- USER INTERACTION
-- ============================================

-- Notifications
vim.notify('Info message', vim.log.levels.INFO)
vim.notify('Warning', vim.log.levels.WARN)
vim.notify('Error', vim.log.levels.ERROR)

-- Input dialog
vim.ui.input({
  prompt = 'Enter value: ',
  default = 'default_value',
}, function(input)
  if input == nil then
    print('Cancelled')
  else
    print('Got input:', input)
  end
end)

-- Selection dialog
vim.ui.select({'Option 1', 'Option 2', 'Option 3'}, {
  prompt = 'Select option:',
  format_item = function(item)
    return 'Option: ' .. item
  end,
}, function(choice, idx)
  if choice == nil then
    print('Cancelled')
  else
    print('Selected:', choice, 'at index', idx)
  end
end)

-- ============================================
-- CONFIGURATION
-- ============================================

-- Set vim options
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.tabstop = 4

-- Global variables (for plugin config)
vim.g.plugin_enabled = true
vim.g.plugin_settings = { key = 'value' }

-- Buffer-local variables
vim.b[bufnr].plugin_state = 'active'

-- Get configuration (if using vim.g pattern)
local config = vim.g.my_plugin_config or {}

-- ============================================
-- FILE SYSTEM (vim.loop / vim.uv)
-- ============================================

-- Read file
local fd = vim.loop.fs_open('/path/to/file', 'r', 438)
local stat = vim.loop.fs_fstat(fd)
local data = vim.loop.fs_read(fd, stat.size, 0)
vim.loop.fs_close(fd)

-- Write file
local fd = vim.loop.fs_open('/path/to/file', 'w', 438)
vim.loop.fs_write(fd, 'content', -1)
vim.loop.fs_close(fd)

-- Check file exists
local stat = vim.loop.fs_stat('/path/to/file')
if stat then
  print('File exists, type:', stat.type)  -- 'file', 'directory', etc.
end

-- Directory operations
vim.loop.fs_mkdir('/path/to/dir', 493)  -- 0755 in octal = 493 in decimal
local handle = vim.loop.fs_scandir('/path/to/dir')
while true do
  local name, type = vim.loop.fs_scandir_next(handle)
  if not name then break end
  print(name, type)
end

-- ============================================
-- DIAGNOSTICS (LSP-related)
-- ============================================

-- Set diagnostics
vim.diagnostic.set(namespace, bufnr, {
  {
    lnum = 0,        -- 0-indexed line
    col = 0,         -- 0-indexed column
    message = 'Error message',
    severity = vim.diagnostic.severity.ERROR,
    source = 'my-plugin',
  }
})

-- Get diagnostics
local diagnostics = vim.diagnostic.get(bufnr)

-- Clear diagnostics
vim.diagnostic.reset(namespace, bufnr)

-- ============================================
-- ASYNC (using vim.schedule)
-- ============================================

-- Run on next event loop iteration
vim.schedule(function()
  print('Deferred execution')
end)

-- Example: async file read pattern
local function read_file_async(path, callback)
  vim.loop.fs_open(path, 'r', 438, function(err, fd)
    if err then
      vim.schedule(function() callback(err, nil) end)
      return
    end
    
    vim.loop.fs_fstat(fd, function(err, stat)
      if err then
        vim.loop.fs_close(fd)
        vim.schedule(function() callback(err, nil) end)
        return
      end
      
      vim.loop.fs_read(fd, stat.size, 0, function(err, data)
        vim.loop.fs_close(fd)
        vim.schedule(function() callback(err, data) end)
      end)
    end)
  end)
end

-- ============================================
-- TREE-SITTER (syntax awareness)
-- ============================================

-- Get parser for current buffer
local parser = vim.treesitter.get_parser(bufnr, 'lua')

-- Get syntax tree
local tree = parser:parse()[1]
local root = tree:root()

-- Query example
local query = vim.treesitter.query.parse('lua', [[
  (function_declaration
    name: (identifier) @function.name)
]])

for id, node, metadata in query:iter_captures(root, bufnr, 0, -1) do
  local name = query.captures[id]
  local text = vim.treesitter.get_node_text(node, bufnr)
  print(name, text)
end

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

-- Deep extend tables (merge configs)
local merged = vim.tbl_deep_extend('force', default_config, user_config)

-- Inspect (pretty-print for debugging)
print(vim.inspect({ complex = { nested = 'table' } }))

-- Execute Vimscript
vim.cmd('echo "Hello from Vimscript"')
vim.cmd([[
  augroup MyGroup
    autocmd!
    autocmd BufEnter * echo "Multi-line Vimscript"
  augroup END
]])

-- Call Vimscript function
local result = vim.fn.input('Prompt: ', 'default')
local exists = vim.fn.filereadable('/path/to/file')
```

### Common Patterns

**Module Structure**
```lua
local M = {}
local config = {
  default_value = true,
}

function M.setup(opts)
  config = vim.tbl_deep_extend('force', config, opts or {})
end

function M.some_function()
  -- implementation
end

return M
```

**Error Handling**
```lua
local ok, result = pcall(function()
  return risky_operation()
end)

if not ok then
  vim.notify('Error: ' .. tostring(result), vim.log.levels.ERROR)
  return nil
end

return result
```

**Floating Window Boilerplate**
```lua
local function create_float()
  local buf = vim.api.nvim_create_buf(false, true)
  local width = 60
  local height = 10
  
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = 'minimal',
    border = 'rounded',
  })
  
  -- Set buffer content
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    'Line 1',
    'Line 2',
  })
  
  -- Close on <Esc> or 'q'
  vim.keymap.set('n', '<Esc>', function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf })
  
  vim.keymap.set('n', 'q', function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf })
  
  return buf, win
end
```

---

## WebSocket vs HTTP Polling

### Current Approach: HTTP Polling

**How it works:**
- `vim.loop.new_timer()` polls `GET /state` every 500ms
- Simple HTTP requests via curl or vim.loop TCP
- Updates UI when state changes detected

**Pros:**
- ✅ Simple implementation (~50 LOC)
- ✅ Works with existing `cn serve` HTTP API
- ✅ No external dependencies
- ✅ Easy to debug (curl can test endpoints)
- ✅ Proven approach (Continue CLI uses same for `cn remote`)

**Cons:**
- ⚠️ Slight latency (max 500ms for updates)
- ⚠️ Constant network traffic (2 req/sec)

### WebSocket Alternative (NOT Recommended)

**Why WebSockets would be better:**
- Real-time updates (no polling delay)
- Lower network overhead
- Bidirectional communication

**Why we DON'T use WebSockets:**

1. **Neovim has NO native WebSocket support**
   - Only has `vim.loop` (TCP sockets)
   - WebSocket requires HTTP upgrade + frame encoding
   - Would need to vendor entire WebSocket library

2. **Implementation complexity:**
   ```
   Option 1: Vendor Lua WebSocket library
   - Need ~1000 LOC WebSocket implementation
   - LuaJIT compatibility issues
   - `cn serve` doesn't expose WebSocket endpoint
   Complexity: 🔴 High

   Option 2: Proxy process
   Neovim ←→ Proxy (Node.js) ←→ cn serve
           stdio/JSON        WebSocket
   - Ship separate Node.js proxy
   - Manage additional process lifecycle
   - More debugging complexity
   Complexity: 🔴 Very High

   Option 3: Implement WebSocket from scratch
   - ~2000+ LOC for spec compliance
   - Fragmentation, ping/pong, handshake
   Complexity: 🔴 Extremely High
   ```

3. **Performance reality check:**
   - 500ms polling = ~10ms latency savings with WebSocket
   - Not noticeable in chat UI
   - HTTP polling overhead is negligible

**Decision: Stick with HTTP polling**
- Good enough for chat use case
- Can tune polling interval based on activity
- Could add WebSocket as opt-in feature later if needed

---

## Dependency Management

### The cn Binary

**Problem:** Plugin depends on `@continuedev/cli` being installed

**What can go wrong:**
1. `cn` not in PATH
2. Wrong Node.js version (need 18+)
3. `cn` installed but outdated version
4. Multiple Node versions (nvm, fnm conflicts)

**Handling Strategy:**

```lua
-- lua/continue/init.lua
local function check_dependencies()
  -- Check if cn exists
  local cn_path = vim.fn.exepath('cn')
  if cn_path == '' then
    vim.notify(
      'Continue.nvim requires the Continue CLI.\n' ..
      'Install: npm install -g @continuedev/cli',
      vim.log.levels.ERROR
    )
    return false
  end

  -- Check Node version
  local node_version = vim.fn.system('node --version')
  local major = tonumber(node_version:match('v(%d+)'))
  if major and major < 18 then
    vim.notify(
      string.format('Continue requires Node.js 18+, found: %s', node_version),
      vim.log.levels.ERROR
    )
    return false
  end

  -- Check cn version (optional but helpful)
  local cn_version = vim.fn.system('cn --version')
  vim.notify(string.format('Using Continue CLI: %s', cn_version:gsub('\n', '')), vim.log.levels.INFO)

  return true
end

function M.setup(opts)
  if not check_dependencies() then
    vim.notify('Continue.nvim: Dependency check failed, plugin disabled', vim.log.levels.WARN)
    return
  end
  -- ... rest of setup
end
```

**User Experience:**
- Clear error messages with installation instructions
- Check on first `:Continue` command, not on Neovim startup
- Provide `:ContinueHealth` command for diagnostics

---

## Port Selection Strategy

### The Problem

**Current docs say:** "use port 8000"

**What breaks:**
- Port 8000 already in use (other dev server)
- Multiple Neovim instances want Continue
- Firewall blocks port 8000

### Proposed Solution

**1. Configurable Port with Auto-increment:**

```lua
-- lua/continue/config.lua
M.config = {
  port = 8000,  -- default
  port_range = { 8000, 8010 },  -- try ports in this range
  auto_find_port = true,
}

-- lua/continue/process.lua
local function find_available_port(start_port, end_port)
  for port = start_port, end_port do
    -- Try to bind to port
    local server = vim.loop.new_tcp()
    local ok = pcall(function()
      server:bind('127.0.0.1', port)
    end)
    server:close()
    
    if ok then
      return port
    end
  end
  return nil
end

function M.start(config)
  local port = config.port
  
  if config.auto_find_port then
    port = find_available_port(
      config.port_range[1],
      config.port_range[2]
    )
    
    if not port then
      vim.notify(
        string.format('No available ports in range %d-%d',
          config.port_range[1], config.port_range[2]),
        vim.log.levels.ERROR
      )
      return false
    end
    
    vim.notify(string.format('Using port %d', port), vim.log.levels.INFO)
  end
  
  -- Start cn serve with found port
  state.port = port
  -- ...
end
```

**2. User Override:**

```lua
-- User can explicitly set port in config
require('continue').setup({
  port = 9000,  -- use this specific port
  auto_find_port = false,  -- don't search
})
```

**3. Handle Port Collisions:**

- If `cn serve` fails to start, check stderr for "port in use"
- Automatically retry with next port
- Store actual port in state for HTTP client to use

---

## State Management Gotchas

### Race Conditions with Polling

**Scenario:** User sends message while agent is streaming

**Timeline:**
```
T=0ms:    Poll returns state (isProcessing: true, streaming message)
T=100ms:  User presses <CR> to send new message
T=200ms:  POST /message queued
T=500ms:  Poll returns state (old message still streaming)
T=1000ms: Poll returns state (new message in queue)
```

**Problem:** UI might briefly show stale state

**Solution 1: Optimistic UI Updates**
```lua
-- Immediately update UI when user sends message
function send_message(text)
  -- Add to local UI immediately
  ui.add_user_message(text)
  
  -- Send to server
  client.post_message(8000, text, function(err, response)
    if err then
      -- Rollback UI update
      ui.remove_last_message()
      vim.notify('Failed to send: ' .. err, vim.log.levels.ERROR)
    end
  end)
end
```

**Solution 2: Debounce User Input**
```lua
-- Disable input while processing
local input_enabled = true

function on_user_input(text)
  if not input_enabled then
    vim.notify('Please wait for current response', vim.log.levels.WARN)
    return
  end
  
  input_enabled = false
  send_message(text, function()
    input_enabled = true
  end)
end
```

**Solution 3: Message IDs (if needed)**
```lua
-- Track which messages we've seen
local seen_message_ids = {}

function update_from_state(state)
  for _, msg in ipairs(state.chatHistory) do
    local msg_id = msg.id or (msg.role .. msg.content:sub(1, 50))
    if not seen_message_ids[msg_id] then
      ui.render_message(msg)
      seen_message_ids[msg_id] = true
    end
  end
end
```

### Concurrent Modification

**Problem:** Polling timer fires while UI is rendering

**Solution:** Use `vim.schedule()` wrapper
```lua
timer:start(0, 500, vim.schedule_wrap(function()
  -- All UI updates happen in main thread
  http.get('/state', function(state)
    -- This callback also wrapped with vim.schedule in http module
    ui.update_from_state(state)
  end)
end))
```

---

## Performance Tuning

### Polling Interval

**Current:** 500ms (2 requests/sec)

**Too aggressive?**
- Depends on use case
- Chat UI: 500ms is fine (humans type slowly)
- Streaming code generation: might want 100ms for smoother updates
- Idle state: could slow down to 2000ms

**Dynamic Polling Strategy:**

```lua
local function get_polling_interval(state)
  if state.isProcessing then
    return 100  -- Fast updates while agent working
  elseif state.messageQueueLength > 0 then
    return 200  -- Medium speed while messages queued
  else
    return 1000  -- Slow when idle
  end
end

function start_polling(port, callback)
  local timer = vim.loop.new_timer()
  
  local function poll()
    http.get('/state', function(state)
      callback(state)
      
      -- Adjust next interval based on state
      local interval = get_polling_interval(state)
      timer:stop()
      timer:start(interval, interval, vim.schedule_wrap(poll))
    end)
  end
  
  timer:start(0, 500, vim.schedule_wrap(poll))
  return timer
end
```

**Measuring Performance:**

```lua
-- Add to http.lua
local stats = {
  request_count = 0,
  total_time = 0,
  errors = 0,
}

function M.get(url, callback)
  local start = vim.loop.hrtime()
  stats.request_count = stats.request_count + 1
  
  -- ... make request ...
  
  local duration = (vim.loop.hrtime() - start) / 1e6  -- ms
  stats.total_time = stats.total_time + duration
  
  -- Log if slow
  if duration > 100 then
    vim.notify(string.format('Slow request: %dms', duration), vim.log.levels.WARN)
  end
end

-- Expose stats
function M.get_stats()
  return {
    requests = stats.request_count,
    avg_time = stats.total_time / stats.request_count,
    errors = stats.errors,
  }
end
```

**User can check:**
```vim
:lua print(vim.inspect(require('continue.utils.http').get_stats()))
" { requests = 1250, avg_time = 15.3, errors = 2 }
```

---

## Security Considerations

### Localhost-Only by Design

**Current approach:**
- `cn serve` binds to `127.0.0.1:8000`
- No authentication
- Plain HTTP (not HTTPS)

**This is INTENTIONAL and acceptable because:**
1. **Local-only traffic** - Never leaves your machine
2. **User's own code** - You trust your own Continue config
3. **Short-lived** - Server auto-stops after timeout
4. **Neovim process** - Same privileges as your editor

### Potential Issues

**Port Forwarding Attack:**
```bash
# Bad actor could do:
ssh -L 8000:localhost:8000 user@victim-machine
# Now they can access victim's Continue server
```

**Mitigation:**
- Document this risk in README
- `cn serve` should reject non-localhost connections (already does)
- Don't expose port through firewall/router

**Network Sniffing:**
- Since it's HTTP not HTTPS, localhost traffic could be sniffed
- In practice: localhost is isolated, not routable
- If paranoid: could add simple token auth

### Recommended Security Best Practices

**Document in README:**
```markdown
## Security Notes

- Continue.nvim starts `cn serve` on localhost only
- No authentication required (local process)
- Do NOT forward the port to external networks
- Do NOT use on untrusted machines
- Server auto-stops after inactivity timeout

If you're concerned about local security:
- Review your `~/.continue/config.json`
- Don't use untrusted MCP servers
- Continue runs with your user's file permissions
```

**Optional: Token Auth (future enhancement)**
```lua
-- Generate random token on startup
local token = vim.fn.system('uuidgen'):gsub('\n', '')

-- Pass to cn serve
vim.fn.jobstart({ 'cn', 'serve', '--token', token })

-- Include in requests
http.post('/message', body, {
  headers = { Authorization = 'Bearer ' .. token }
})
```

**Not worth it for v1** - adds complexity for minimal gain

---

## Resources

### Neovim Plugin Development
- [Neovim Lua Guide](https://neovim.io/doc/user/lua-guide.html) - Official documentation
- [nvim-lua-guide](https://github.com/nanotee/nvim-lua-guide) - Community guide
- [Learn Lua in Y Minutes](https://learnxinyminutes.com/docs/lua/) - Quick Lua syntax
- [Neovim API Documentation](https://neovim.io/doc/user/api.html) - API reference
- [How to write Neovim plugins](https://github.com/nvim-lua/wishlist/wiki/How-to-write-a-plugin) - Best practices

### Essential Libraries
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) - Lua utilities (async, path, etc.)
- [nui.nvim](https://github.com/MunifTanjim/nui.nvim) - UI components
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) - Fuzzy finder (good UI patterns)

### Example Plugins (Study These)
- [Comment.nvim](https://github.com/numToStr/Comment.nvim) - Simple, well-structured
- [gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim) - Advanced, uses libuv extensively
- [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) - Complex, event-driven architecture

### Tree-sitter
- [Tree-sitter Documentation](https://tree-sitter.github.io/tree-sitter/)
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) - Integration layer

### Plugin Distribution
- [lazy.nvim](https://github.com/folke/lazy.nvim) - Most popular plugin manager
- [packer.nvim](https://github.com/wbthomason/packer.nvim) - Also popular
- [rocks.nvim](https://github.com/nvim-neorocks/rocks.nvim) - LuaRocks-based

### Neovim Community
- [r/neovim](https://www.reddit.com/r/neovim/) - Reddit community
- [Neovim Discourse](https://neovim.discourse.group/) - Official forum
- [Matrix Chat](https://matrix.to/#/#neovim:matrix.org) - Real-time help

---

## Contact & Support

**For Humans:**
- Primary maintainer: [TBD]
- Issue tracker: [TBD]
- Discussion forum: [TBD]

**For LLMs:**
- You have all the context you need in this file
- Ask clarifying questions before making assumptions
- Document non-obvious decisions as you go
- Update this file when you learn something new

---

## Changelog

### [Unreleased]
- Initial project knowledge base created
- Target platform: Neovim (Lua)
- Source options: VSCode (TypeScript) or JetBrains (Kotlin)
- **Recommendation**: Port from VSCode (~40-70K tokens vs ~80-120K from JetBrains)
- Key advantages of VSCode source:
  - Simpler, more linear code structure
  - Better documented, more examples in training data
  - Closer conceptual model (async/event-driven)
  - Less impedance mismatch with Lua
- API mapping cheatsheet created for common patterns

### Rationale for VSCode Choice

**Technical Alignment:**
- TypeScript → Lua translation is more natural than Kotlin → Lua
- Both use event-driven architecture (vs JetBrains' heavy OOP)
- VSCode's flat API surface maps better to Neovim's functional style
- JSON configs translate cleanly to Lua tables

**LLM Efficiency:**
- More TypeScript/JS patterns in training data
- VSCode extensions are smaller, more focused codebases
- Less "framework noise" to parse through
- Token cost approximately 50% of JetBrains route

**Practical Benefits:**
- Faster iteration cycles (less boilerplate)
- Easier to extract core business logic
- Better community examples for reference
- Simpler testing story

---

*Last updated: 2025-10-25*
*Next review: After choosing source plugin and analyzing its feature set*