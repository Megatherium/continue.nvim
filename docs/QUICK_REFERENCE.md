# Quick Reference Card

One-page cheatsheet for Neovim plugin porting. Print this out or keep it open while coding.

## The Decision (Copy & Paste This)

```
✅ Port from: VSCode (TypeScript)
📊 Cost: ~40-70K tokens
❌ Avoid: JetBrains (2x more expensive)
```

## Common API Translations

### Commands
```lua
-- VSCode: vscode.commands.registerCommand(...)
vim.api.nvim_create_user_command('CmdName', fn, {desc = '...'})
```

### Config
```lua
-- VSCode: vscode.workspace.getConfiguration('section')
local M = { config = { setting = true } }
function M.setup(opts) 
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})
end
```

### Input
```lua
-- VSCode: await vscode.window.showInputBox({...})
vim.ui.input({prompt = 'Enter: '}, function(input) end)
```

### Selection
```lua
-- VSCode: await vscode.window.showQuickPick([...])
vim.ui.select({'a', 'b'}, {prompt = 'Pick:'}, function(choice) end)
```

### Notifications
```lua
-- VSCode: vscode.window.showInformationMessage(...)
vim.notify('Message', vim.log.levels.INFO)
```

### File Operations
```lua
-- VSCode: await vscode.workspace.fs.readFile(uri)
local file = io.open(path, 'r')
local content = file:read('*a')
file:close()
```

### Text Editing
```lua
-- VSCode: editor.edit(builder => builder.insert(...))
vim.api.nvim_buf_set_text(bufnr, row, col, row, col, {'text'})
```

### Events
```lua
-- VSCode: workspace.onDidChangeTextDocument(...)
vim.api.nvim_create_autocmd('TextChanged', {callback = fn})
```

## Critical Gotchas

### Indexing
```lua
-- Buffers/lines: 0-indexed (like VSCode)
local bufnr = 0  -- current buffer
vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)  -- first line

-- Lua tables: 1-indexed (DIFFERENT from VSCode!)
local items = {'a', 'b', 'c'}
local first = items[1]  -- NOT items[0]
```

### Async Patterns
```lua
-- No async/await! Use callbacks:
some_async_op(function(result)
  vim.schedule(function()
    -- Use result in main thread
  end)
end)

-- Or plenary.async (recommended):
local async = require('plenary.async')
async.run(function()
  local result = async_op()
end)
```

### Error Handling
```lua
-- No try/catch! Use pcall:
local ok, result = pcall(risky_function)
if not ok then
  vim.notify('Error: ' .. tostring(result), vim.log.levels.ERROR)
  return
end
```

### Module Hot Reload
```lua
-- Clear cache to reload:
package.loaded['plugin-name'] = nil
require('plugin-name').setup()
```

## Essential APIs (Top 10)

```lua
-- 1. User commands
vim.api.nvim_create_user_command('Name', fn, {desc = '...'})

-- 2. Autocommands
vim.api.nvim_create_autocmd('Event', {callback = fn})

-- 3. Keymaps
vim.keymap.set('n', '<leader>x', fn, {desc = '...'})

-- 4. Notifications
vim.notify('Message', vim.log.levels.INFO)

-- 5. Input/Select
vim.ui.input({prompt = '...'}, fn)
vim.ui.select({'a', 'b'}, {prompt = '...'}, fn)

-- 6. Buffers
vim.api.nvim_get_current_buf()
vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

-- 7. Windows
vim.api.nvim_get_current_win()
vim.api.nvim_open_win(bufnr, true, {relative = 'editor', ...})

-- 8. Config
vim.tbl_deep_extend('force', defaults, user_opts)

-- 9. Schedule (defer execution)
vim.schedule(function() end)

-- 10. Inspect (debug print)
print(vim.inspect(complex_table))
```

## Plugin Structure Template

```lua
-- lua/plugin-name/init.lua
local M = {}

M.config = {
  enabled = true,
  -- other defaults
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})
  
  -- Register commands
  vim.api.nvim_create_user_command('PluginCmd', function()
    M.do_thing()
  end, {desc = 'Description'})
  
  -- Set up autocommands
  local augroup = vim.api.nvim_create_augroup('PluginName', {clear = true})
  vim.api.nvim_create_autocmd('BufEnter', {
    group = augroup,
    callback = function() end,
  })
end

function M.do_thing()
  -- Implementation
end

return M
```

## Debugging Snippets

```lua
-- Print to messages
print(vim.inspect(data))

-- Visual notification
vim.notify('Debug: ' .. vim.inspect(data), vim.log.levels.DEBUG)

-- Log to file
local log = io.open('/tmp/plugin.log', 'a')
log:write(os.date() .. ' ' .. vim.inspect(data) .. '\n')
log:close()

-- Check if value exists
if vim.api.nvim_buf_is_valid(bufnr) then
  -- safe to use
end
```

## Testing Pattern

```lua
-- tests/plugin_spec.lua
local plugin = require('plugin-name')

describe('plugin', function()
  before_each(function()
    plugin.setup({})
  end)
  
  it('loads without errors', function()
    assert.is_not_nil(plugin)
  end)
  
  it('registers commands', function()
    local commands = vim.api.nvim_get_commands({})
    assert.is_not_nil(commands.PluginCmd)
  end)
end)
```

## Performance Tips

```lua
-- Batch operations
local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
-- modify lines in Lua
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

-- Cache expensive calls
local cache = {}
function get_thing(key)
  if not cache[key] then
    cache[key] = expensive_operation(key)
  end
  return cache[key]
end

-- Defer non-critical work
vim.schedule(function()
  -- This runs later
end)
```

## Common Mistakes to Avoid

❌ `local M = {}` without `return M` at end  
❌ `items[0]` (Lua tables are 1-indexed!)  
❌ Forgetting `vim.schedule()` in async callbacks  
❌ Not checking `pcall()` status before using result  
❌ Creating autocommands without augroup (causes duplicates)  
❌ Not making commands buffer-local when appropriate  
❌ Using `print()` without `vim.inspect()` for tables  

## Installation Testing

```lua
-- User's config (lazy.nvim example)
{
  'your-name/plugin-name.nvim',
  config = function()
    require('plugin-name').setup({
      enabled = true,
    })
  end,
}
```

```bash
# Test in clean environment
nvim --clean -u minimal_init.lua

# minimal_init.lua:
-- Add plugin manager and your plugin
-- Test basic functionality
```

## When You're Stuck

1. **Check the docs**: `:help vim.api` or `:help lua-guide`
2. **Inspect values**: `print(vim.inspect(value))`
3. **Study examples**: Look at Comment.nvim, gitsigns.nvim
4. **Ask for help**: r/neovim, Neovim Discord
5. **Read the source**: Neovim's runtime/lua/vim/ is readable Lua

## Token Budget Awareness (For LLMs)

- Lua is concise: typically 40-60% of TypeScript LOC
- Use `str_replace` for edits, not full rewrites
- Create new files in one go when they're under 100 lines
- Test incrementally (don't write entire plugin at once)
- Ask for clarification before making assumptions

---

**Next Steps**:
1. Read [EXECUTIVE_SUMMARY.md](EXECUTIVE_SUMMARY.md) for the full picture
2. Use [API_MAPPING.md](API_MAPPING.md) for detailed translations
3. Track progress with [PORTING_CHECKLIST.md](PORTING_CHECKLIST.md)
