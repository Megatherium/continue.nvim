# Project Knowledge Base

## Architecture Overview

### Current Status
- **Phase**: Initial planning / porting evaluation
- **Base Sources**: 
  - Option A: JetBrains plugin (Kotlin)
  - Option B: VSCode extension (TypeScript)
- **Target**: Neovim plugin (Lua)
- **Primary Language**: Lua 5.1/LuaJIT

### Design Decisions

#### Source Plugin Choice for Porting
**Decision**: [Pending - Analysis below]

**RECOMMENDATION: Port from VSCode (TypeScript)**

#### Porting Path Comparison

**VSCode → Neovim (RECOMMENDED)**
- Pros:
  - Simpler, more linear code structure
  - Less abstraction layers to decode
  - Better documented patterns
  - Closer conceptual model (async, event-driven)
  - JSON config → Lua tables (natural translation)
- Cons:
  - May rely on Node.js ecosystem (need pure Lua alternatives)
- Estimated effort: 40-70K tokens

**JetBrains → Neovim**
- Pros:
  - More feature-complete (might have richer functionality)
  - Better separation of concerns (could be cleaner to port)
- Cons:
  - Heavy OOP/enterprise patterns → procedural Lua (impedance mismatch)
  - PSI/threading concepts don't map to Neovim
  - Gradle/Kotlin DSL noise obscures actual logic
  - More boilerplate to strip away
- Estimated effort: 80-120K tokens

#### Technology Stack (Proposed - Neovim Target)

```
Neovim Plugin Architecture
├── Lua 5.1/LuaJIT (Neovim embedded)
├── Neovim API (nvim_*)
├── Tree-sitter (optional, for syntax awareness)
└── No build step (Lua is interpreted)

Plugin Structure
├── lua/
│   └── plugin-name/
│       ├── init.lua              # Entry point
│       ├── config.lua            # User configuration
│       ├── commands.lua          # Ex commands
│       ├── mappings.lua          # Key bindings
│       ├── autocmds.lua          # Autocommands
│       └── utils.lua             # Helpers
├── plugin/
│   └── plugin-name.vim          # Legacy Vimscript shim (optional)
├── doc/
│   └── plugin-name.txt          # Vim help docs
└── README.md

Dependencies (Minimal Approach)
├── Core: Neovim 0.8+ (or 0.9+ for newer APIs)
├── Optional: plenary.nvim (common utilities)
└── Optional: nui.nvim (UI components)
```

#### Key Architectural Differences

**VSCode → Neovim Mapping**
```
VSCode Extension Host    → Neovim embedded Lua VM
Activation events        → VimEnter, FileType autocommands
Commands                 → vim.api.nvim_create_user_command()
Configuration            → vim.g variables or lua modules
Output Channel           → vim.notify() or custom buffer
Quick Pick               → vim.ui.select()
Input Box                → vim.ui.input()
WebView                  → Floating windows (limited)
Language Server          → Built-in LSP client
Diagnostics              → vim.diagnostic.*
```

**JetBrains → Neovim Mapping**
```
Action System            → User commands + keymaps
PSI Tree                 → Tree-sitter queries
Virtual File System      → vim.loop (libuv) filesystem
Notifications            → vim.notify()
Settings Service         → Lua tables in config
Read/Write Actions       → Not needed (single-threaded)
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
