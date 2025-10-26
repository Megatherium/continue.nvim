# Neovim Plugin Porting Documentation

Complete knowledge base for porting JetBrains or VSCode plugins to Neovim.

## Quick Navigation

📋 **[EXECUTIVE_SUMMARY.md](EXECUTIVE_SUMMARY.md)** - Start here! TL;DR and decision rationale  
📚 **[PROJECT_KNOWLEDGE.md](PROJECT_KNOWLEDGE.md)** - Deep dive: architecture, pain points, APIs  
🔄 **[API_MAPPING.md](API_MAPPING.md)** - VSCode/JetBrains → Neovim API translations  
✅ **[PORTING_CHECKLIST.md](PORTING_CHECKLIST.md)** - Step-by-step tracking tool  

## The Decision

**Port from the VSCode extension** (TypeScript).

- **Cost**: ~40-70K tokens
- **Difficulty**: 1.0x (baseline)
- **Why**: Better language/API alignment, more LLM training data, less boilerplate

vs.

**JetBrains** (Kotlin):
- **Cost**: ~80-120K tokens (2x more expensive!)
- **Difficulty**: 2.0x (heavy OOP, complex APIs)

## Documentation Overview

### [EXECUTIVE_SUMMARY.md](EXECUTIVE_SUMMARY.md)
Perfect for getting oriented quickly. Answers:
- Which plugin should I port from?
- What's the cost difference?
- What are the main challenges?
- How do I get started?

**Read this first if you're new to the project.**

### [PROJECT_KNOWLEDGE.md](PROJECT_KNOWLEDGE.md)
The comprehensive knowledge base. Contains:
- Architecture overview and design decisions
- Neovim-specific pain points and gotchas
- Detailed API reference with code examples
- Development guidelines for humans and LLMs
- Resource links and community info

**Read this when you're ready to start coding.**

### [API_MAPPING.md](API_MAPPING.md)
Translation guide between platforms. Includes:
- Side-by-side API comparisons
- VSCode → Neovim mappings (commands, config, events, etc.)
- JetBrains → Neovim mappings (actions, PSI, notifications, etc.)
- Common pitfalls (indexing, async patterns, error handling)
- Code examples for every pattern

**Keep this open while porting for quick lookups.**

### [PORTING_CHECKLIST.md](PORTING_CHECKLIST.md)
Practical tracking tool. Includes:
- Pre-port analysis worksheet
- Feature inventory template
- Phase-by-phase checklist (Foundation → Core → Features → Polish → Release)
- Metrics tracking
- Lessons learned section

**Copy this file and fill it out for your specific project.**

## Quick Start Guide

### For Humans

```bash
# 1. Read the executive summary
cat EXECUTIVE_SUMMARY.md

# 2. Analyze your source plugin
# For VSCode:
cat package.json        # Commands, config
cat src/extension.ts    # Entry point

# 3. Set up your Neovim plugin structure
mkdir -p lua/your-plugin
cd lua/your-plugin

# 4. Create initial files
cat > init.lua << 'EOF'
local M = {}
M.config = {}
function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})
end
return M
EOF

# 5. Link to your Neovim config for testing
ln -s $(pwd) ~/.config/nvim/lua/your-plugin

# 6. Test it loads
nvim -c "lua require('your-plugin').setup()"
```

### For LLMs

When starting a porting task:

1. **Read PROJECT_KNOWLEDGE.md first** - Get full context
2. **Check API_MAPPING.md** - Find equivalent APIs
3. **Reference PORTING_CHECKLIST.md** - Track progress
4. **Use targeted edits** - Prefer `str_replace` over full file rewrites
5. **Build incrementally** - One command at a time, test frequently

Remember:
- Lua is 1-indexed for tables (but 0-indexed for buffers/lines!)
- No async/await (use callbacks or plenary.async)
- All requires are cached (clear package.loaded for hot reload)
- Use `vim.schedule()` for deferred execution

## Project Structure

```
your-neovim-plugin/
├── lua/
│   └── your-plugin/
│       ├── init.lua          # Entry point, setup()
│       ├── config.lua        # Configuration defaults
│       ├── commands.lua      # User command definitions
│       ├── autocmds.lua      # Autocommand setup
│       ├── mappings.lua      # Keybinding definitions
│       └── utils.lua         # Helper functions
├── plugin/
│   └── your-plugin.vim       # Legacy Vimscript shim (optional)
├── doc/
│   └── your-plugin.txt       # Vim help documentation
├── tests/
│   └── your-plugin_spec.lua  # Plenary tests
├── README.md                 # User-facing documentation
├── CHANGELOG.md              # Version history
└── LICENSE                   # License file
```

## Development Workflow

### Hot Reload

```vim
" In Neovim, while developing:
:lua package.loaded['your-plugin'] = nil
:lua require('your-plugin').setup()

" Or create a command:
:command! Reload lua package.loaded['your-plugin'] = nil; require('your-plugin').setup()
```

### Debugging

```lua
-- Print debugging
print(vim.inspect(some_table))

-- Visual notification
vim.notify('Debug: ' .. tostring(value), vim.log.levels.DEBUG)

-- Log to file
local log = io.open('/tmp/plugin.log', 'a')
log:write(vim.inspect(data) .. '\n')
log:close()
```

### Testing

```bash
# Using plenary.nvim
nvim --headless -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"
```

## Key Neovim Concepts

### Module Pattern
```lua
local M = {}

-- Private state
local internal = {}

-- Public API
function M.setup(opts)
  -- configuration
end

function M.public_function()
  -- implementation
end

return M
```

### Command Registration
```lua
vim.api.nvim_create_user_command('CommandName', function(opts)
  -- Implementation
end, {
  desc = 'Description for :Telescope commands',
  nargs = '*',
  bang = true,
})
```

### Autocommands
```lua
local augroup = vim.api.nvim_create_augroup('PluginName', { clear = true })

vim.api.nvim_create_autocmd('BufEnter', {
  group = augroup,
  pattern = '*.lua',
  callback = function(args)
    -- Implementation
  end,
})
```

## Resources

### Essential Reading
- [Neovim Lua Guide](https://neovim.io/doc/user/lua-guide.html)
- [nvim-lua-guide](https://github.com/nanotee/nvim-lua-guide)
- [Neovim API docs](https://neovim.io/doc/user/api.html)

### Example Plugins to Study
- [Comment.nvim](https://github.com/numToStr/Comment.nvim) - Simple, clean structure
- [gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim) - Advanced async patterns
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) - Complex UI

### Common Dependencies
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) - Lua utilities, async lib
- [nui.nvim](https://github.com/MunifTanjim/nui.nvim) - UI components

## Contributing to This Documentation

Found something missing or incorrect? This documentation should evolve as you learn:

1. Update the relevant .md file
2. Document new patterns in API_MAPPING.md
3. Add pain points to PROJECT_KNOWLEDGE.md
4. Share lessons learned in PORTING_CHECKLIST.md

## License

This documentation is provided as-is for your porting project. Use, modify, and share freely.

---

**Ready to start?** → [Read the Executive Summary](EXECUTIVE_SUMMARY.md)

**Need API translations?** → [Check the API Mapping](API_MAPPING.md)

**Ready to code?** → [Dive into Project Knowledge](PROJECT_KNOWLEDGE.md)

**Want to track progress?** → [Use the Checklist](PORTING_CHECKLIST.md)
