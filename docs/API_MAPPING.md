# API Mapping Cheatsheet: VSCode/JetBrains → Neovim

This document maps common patterns from VSCode and JetBrains plugins to their Neovim equivalents.

## VSCode → Neovim Mappings

### Activation & Lifecycle

| VSCode | Neovim |
|--------|--------|
| `activate()` | `require('plugin').setup()` |
| `deactivate()` | No explicit deactivation (optional cleanup) |
| `activationEvents: ["onLanguage:python"]` | `vim.api.nvim_create_autocmd('FileType', { pattern = 'python' })` |
| `context.subscriptions.push(disposable)` | Store references, no auto-cleanup |

### Commands

```typescript
// VSCode
vscode.commands.registerCommand('extension.myCommand', () => {
  vscode.window.showInformationMessage('Hello');
});
```

```lua
-- Neovim
vim.api.nvim_create_user_command('MyCommand', function()
  vim.notify('Hello', vim.log.levels.INFO)
end, { desc = 'My command description' })
```

### Configuration

```typescript
// VSCode - package.json
"contributes": {
  "configuration": {
    "properties": {
      "myExt.enabled": {
        "type": "boolean",
        "default": true
      }
    }
  }
}

// VSCode - reading config
const config = vscode.workspace.getConfiguration('myExt');
const enabled = config.get('enabled', true);

// VSCode - watching config changes
vscode.workspace.onDidChangeConfiguration(e => {
  if (e.affectsConfiguration('myExt.enabled')) {
    // reload
  }
});
```

```lua
-- Neovim - setup pattern
local M = {}
M.config = {
  enabled = true,
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})
end

-- Neovim - reading config
local enabled = require('my-plugin').config.enabled

-- Neovim - no built-in config watching
-- Users manually call setup() again or restart
```

### User Input

```typescript
// VSCode - input box
const result = await vscode.window.showInputBox({
  prompt: 'Enter value',
  value: 'default',
});

// VSCode - quick pick
const choice = await vscode.window.showQuickPick(
  ['Option 1', 'Option 2'],
  { placeHolder: 'Select one' }
);
```

```lua
-- Neovim - input
vim.ui.input({
  prompt = 'Enter value: ',
  default = 'default',
}, function(result)
  if result then
    -- handle input
  end
end)

-- Neovim - selection
vim.ui.select({'Option 1', 'Option 2'}, {
  prompt = 'Select one:',
}, function(choice, idx)
  if choice then
    -- handle choice
  end
end)
```

### Text Editing

```typescript
// VSCode - edit current document
const editor = vscode.window.activeTextEditor;
editor.edit(editBuilder => {
  const position = new vscode.Position(0, 0);
  editBuilder.insert(position, 'text');
  
  const range = new vscode.Range(
    new vscode.Position(0, 0),
    new vscode.Position(0, 10)
  );
  editBuilder.replace(range, 'new text');
});
```

```lua
-- Neovim - edit current buffer
local bufnr = vim.api.nvim_get_current_buf()

-- Insert at line 1, column 0 (0-indexed)
vim.api.nvim_buf_set_text(bufnr, 0, 0, 0, 0, {'text'})

-- Replace range (line 0, col 0 to line 0, col 10)
vim.api.nvim_buf_set_text(bufnr, 0, 0, 0, 10, {'new text'})

-- Or manipulate full lines
local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
lines[1] = 'modified line'
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
```

### File Operations

```typescript
// VSCode - read file
const uri = vscode.Uri.file('/path/to/file');
const bytes = await vscode.workspace.fs.readFile(uri);
const content = new TextDecoder().decode(bytes);

// VSCode - write file
const bytes = new TextEncoder().encode('content');
await vscode.workspace.fs.writeFile(uri, bytes);
```

```lua
-- Neovim - read file (sync)
local file = io.open('/path/to/file', 'r')
if file then
  local content = file:read('*a')
  file:close()
end

-- Neovim - write file (sync)
local file = io.open('/path/to/file', 'w')
if file then
  file:write('content')
  file:close()
end

-- Neovim - async with vim.loop
vim.loop.fs_open('/path/to/file', 'r', 438, function(err, fd)
  if not err then
    vim.loop.fs_fstat(fd, function(err, stat)
      vim.loop.fs_read(fd, stat.size, 0, function(err, data)
        vim.loop.fs_close(fd)
        vim.schedule(function()
          -- use data in main thread
        end)
      end)
    end)
  end
end)
```

### Diagnostics

```typescript
// VSCode - create diagnostic collection
const diagnostics = vscode.languages.createDiagnosticCollection('myExt');

// VSCode - set diagnostics
diagnostics.set(uri, [
  new vscode.Diagnostic(
    new vscode.Range(0, 0, 0, 10),
    'Error message',
    vscode.DiagnosticSeverity.Error
  ),
]);

// VSCode - clear diagnostics
diagnostics.clear();
```

```lua
-- Neovim - create namespace
local ns = vim.api.nvim_create_namespace('my-plugin')

-- Neovim - set diagnostics
vim.diagnostic.set(ns, bufnr, {
  {
    lnum = 0,  -- 0-indexed line
    col = 0,   -- 0-indexed column
    end_lnum = 0,
    end_col = 10,
    message = 'Error message',
    severity = vim.diagnostic.severity.ERROR,
    source = 'my-plugin',
  },
})

-- Neovim - clear diagnostics
vim.diagnostic.reset(ns, bufnr)
```

### Event Handlers

```typescript
// VSCode - document change
vscode.workspace.onDidChangeTextDocument(event => {
  console.log('Document changed:', event.document.uri);
});

// VSCode - document save
vscode.workspace.onDidSaveTextDocument(document => {
  console.log('Document saved:', document.uri);
});

// VSCode - window focus
vscode.window.onDidChangeActiveTextEditor(editor => {
  if (editor) {
    console.log('Active editor changed');
  }
});
```

```lua
-- Neovim - document change
vim.api.nvim_create_autocmd('TextChanged', {
  callback = function()
    print('Document changed')
  end,
})

-- Neovim - document save
vim.api.nvim_create_autocmd('BufWritePost', {
  callback = function(args)
    print('Document saved:', args.file)
  end,
})

-- Neovim - buffer focus
vim.api.nvim_create_autocmd('BufEnter', {
  callback = function(args)
    print('Buffer entered:', args.buf)
  end,
})
```

---

## JetBrains → Neovim Mappings

### Actions

```kotlin
// JetBrains - define action
class MyAction : AnAction("My Action") {
  override fun actionPerformed(e: AnActionEvent) {
    val project = e.project ?: return
    Messages.showMessageDialog(
      project,
      "Hello!",
      "Title",
      Messages.getInformationIcon()
    )
  }
}
```

```lua
-- Neovim - equivalent
vim.api.nvim_create_user_command('MyAction', function()
  vim.notify('Hello!', vim.log.levels.INFO)
end, { desc = 'My Action' })

-- With keybinding
vim.keymap.set('n', '<leader>ma', ':MyAction<CR>', { desc = 'My Action' })
```

### PSI / Syntax Trees

```kotlin
// JetBrains - PSI traversal
ReadAction.run<RuntimeException> {
  val psiFile = PsiManager.getInstance(project).findFile(virtualFile)
  psiFile?.accept(object : PsiRecursiveElementVisitor() {
    override fun visitElement(element: PsiElement) {
      if (element is PsiMethod) {
        println("Found method: ${element.name}")
      }
      super.visitElement(element)
    }
  })
}
```

```lua
-- Neovim - Tree-sitter equivalent
local parser = vim.treesitter.get_parser(bufnr, 'java')
local tree = parser:parse()[1]
local root = tree:root()

local query = vim.treesitter.query.parse('java', [[
  (method_declaration
    name: (identifier) @method.name)
]])

for id, node in query:iter_captures(root, bufnr, 0, -1) do
  local text = vim.treesitter.get_node_text(node, bufnr)
  print('Found method:', text)
end
```

### Notifications

```kotlin
// JetBrains - notification
Notifications.Bus.notify(
  Notification(
    "NotificationGroup",
    "Title",
    "Content",
    NotificationType.INFORMATION
  ),
  project
)
```

```lua
-- Neovim - notification
vim.notify('Content', vim.log.levels.INFO)

-- Or with title (requires plugin like nvim-notify)
require('notify')('Content', 'info', { title = 'Title' })
```

### Settings/Configuration

```kotlin
// JetBrains - persistent settings
@State(
  name = "MySettings",
  storages = [Storage("MySettings.xml")]
)
class MySettings : PersistentStateComponent<MySettings.State> {
  data class State(
    var enabled: Boolean = true,
    var value: String = "default"
  )
  
  private var state = State()
  
  override fun getState() = state
  override fun loadState(state: State) {
    this.state = state
  }
}

// Usage
val settings = ServiceManager.getService(MySettings::class.java)
settings.state.enabled = false
```

```lua
-- Neovim - config pattern (no persistence by default)
local M = {}

M.config = {
  enabled = true,
  value = 'default',
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})
  
  -- Optional: persist to file
  local config_path = vim.fn.stdpath('data') .. '/my-plugin.json'
  local file = io.open(config_path, 'w')
  if file then
    file:write(vim.json.encode(M.config))
    file:close()
  end
end

-- Optional: load persisted config
local function load_config()
  local config_path = vim.fn.stdpath('data') .. '/my-plugin.json'
  local file = io.open(config_path, 'r')
  if file then
    local content = file:read('*a')
    file:close()
    return vim.json.decode(content)
  end
  return {}
end

return M
```

### Virtual File System

```kotlin
// JetBrains - VFS operations
val vfs = VirtualFileManager.getInstance()
val file = vfs.findFileByUrl("file:///path/to/file")

if (file != null && file.isValid) {
  val content = String(file.contentsToByteArray())
  println(content)
}
```

```lua
-- Neovim - file operations
local path = '/path/to/file'

-- Check if file exists
local stat = vim.loop.fs_stat(path)
if stat and stat.type == 'file' then
  local file = io.open(path, 'r')
  if file then
    local content = file:read('*a')
    file:close()
    print(content)
  end
end
```

---

## Common Pitfalls When Porting

### 1. Zero-based vs One-based Indexing

```typescript
// VSCode/JetBrains (0-indexed)
const line = 0;  // first line
const char = 0;  // first character
```

```lua
-- Neovim buffers (0-indexed)
local line = 0  -- first line

-- Neovim Lua tables (1-indexed!)
local lines = {'first', 'second', 'third'}
local first = lines[1]  -- NOT lines[0]

-- Tree-sitter (0-indexed)
local range = node:range()  -- {0, 0, 0, 10}
```

### 2. Async Patterns

```typescript
// VSCode - async/await
async function doThing() {
  const result = await someAsyncOp();
  return result;
}
```

```lua
-- Neovim - callbacks (without plenary)
local function do_thing(callback)
  some_async_op(function(result)
    callback(result)
  end)
end

-- Or with plenary.async
local async = require('plenary.async')
local do_thing = async.wrap(function(callback)
  some_async_op(callback)
end, 1)

async.run(function()
  local result = do_thing()
  -- use result
end)
```

### 3. Error Handling

```typescript
// VSCode/JetBrains - exceptions
try {
  riskyOperation();
} catch (error) {
  console.error(error);
}
```

```lua
-- Neovim - pcall
local ok, result = pcall(risky_operation)
if not ok then
  vim.notify('Error: ' .. tostring(result), vim.log.levels.ERROR)
  return
end
-- use result
```

### 4. Module System

```typescript
// VSCode - ES modules
import { foo } from './utils';
export function bar() { }
```

```lua
-- Neovim - require/return
local utils = require('plugin.utils')
local M = {}

function M.bar()
  utils.foo()
end

return M
```

---

## Performance Considerations

### VSCode/JetBrains
- Async by default, can offload to background threads
- Rich UI rendering (WebViews, custom components)

### Neovim
- Single-threaded (use vim.loop for async I/O)
- Minimal UI (creative use of buffers/windows)
- Direct access to editor state (faster for text operations)

**Rules of thumb:**
1. Use `vim.schedule()` to defer non-critical work
2. Batch buffer operations when possible
3. Cache expensive computations
4. Avoid tight loops in Lua (drop to Vimscript if needed)

---

## Testing Strategy

### VSCode
```typescript
// test/suite/extension.test.ts
import * as assert from 'assert';
import * as vscode from 'vscode';

suite('Extension Test Suite', () => {
  test('Command is registered', async () => {
    const commands = await vscode.commands.getCommands();
    assert.ok(commands.includes('extension.myCommand'));
  });
});
```

### Neovim
```lua
-- tests/my_test_spec.lua (using plenary)
local plugin = require('my-plugin')

describe('plugin', function()
  it('can be required', function()
    assert.is_not_nil(plugin)
  end)
  
  it('has setup function', function()
    assert.is_function(plugin.setup)
  end)
end)
```

Run with: `nvim --headless -c "PlenaryBustedDirectory tests/"`

---

*This is a living document. Update as you encounter new patterns during porting.*
