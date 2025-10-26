# Project Context: Continue Plugin Port

## What We're Doing

Porting an existing plugin to Neovim (Lua).

**Source**: VSCode extension (TypeScript) of contiudev/continue
**Target**: Neovim plugin (Lua)  
**Status**: [UPDATE THIS - e.g., "Phase 2: Core Logic"]

## Quick Facts

- **Decision**: Port from VSCode, not JetBrains (~50% cheaper in tokens/effort)
- **Plugin Name**: Continue - AI code assistant
- **Main Features**: Agent, Chat, Edit, Autocomplete
- **Estimated effort**: 40-70K tokens
- **LOC reduction**: Expect 30-40% less code in Lua vs TypeScript
- **Key challenges**:
  - AI/LLM integration (need to handle API calls to various AI providers)
  - WebView GUI → Neovim floating windows/buffers
  - Autocomplete integration with Neovim's completion system
  - Async streaming responses from LLM APIs

## File Structure

```
repo/
├── source/                        # continuedev/continue as a submodule
│   └── extensions/vscode/         # THIS is what we're porting
├── lua/
│   └── continue-nvim/
│       ├── init.lua               # Entry point & setup()
│       ├── config/
│       │   └── init.lua           # Configuration schema & defaults
│       ├── chat/
│       │   └── init.lua           # Chat functionality
│       ├── edit/
│       │   └── init.lua           # Inline edit functionality
│       ├── autocomplete/
│       │   └── init.lua           # AI autocomplete integration
│       ├── agent/
│       │   └── init.lua           # Agent/task automation
│       ├── ui/
│       │   ├── floating.lua       # Floating windows
│       │   └── buffers.lua        # Buffer management
│       └── utils/
│           ├── llm.lua            # LLM API client
│           └── async.lua          # Async helpers
├── plugin/
│   └── continue-nvim.lua          # Auto-load commands
├── doc/
│   └── continue-nvim.txt          # Vim help docs
├── docs/                          # Porting documentation
│   ├── PROJECT_KNOWLEDGE.md       # Architecture, gotchas, APIs
│   ├── API_MAPPING.md             # VSCode → Neovim translations
│   ├── QUICK_REFERENCE.md         # One-page cheatsheet
│   └── PORTING_CHECKLIST.md       # Progress tracker
└── CLAUDE.md                      # This file
```

## When You're Asked To...

### Analyze source code
1. Read `docs/API_MAPPING.md` for translation patterns
2. Focus on: commands, config schema, event handlers
3. Update `docs/PORTING_CHECKLIST.md` with findings

### Implement a feature
1. Check `docs/QUICK_REFERENCE.md` for common patterns
2. Use Morph for file edits (it's installed, more efficient than native)
3. Remember: Lua tables are 1-indexed, buffers are 0-indexed
4. Module pattern: `local M = {}` ... `return M`

### Debug something
1. Check `docs/PROJECT_KNOWLEDGE.md` > Pain Points & Gotchas
2. Common issues: module caching, pcall error handling, vim.schedule for async
3. Debug pattern: `print(vim.inspect(value))`

### Test changes
```bash
# Hot reload without restarting Neovim:
:lua package.loaded['plugin-name'] = nil
:lua require('plugin-name').setup()
```

## Critical Reminders

**Lua Gotchas:**
- Arrays/tables: `items[1]` not `items[0]`
- No async/await: use callbacks or plenary.async
- No try/catch: use `pcall(fn)` → `(ok, result)`
- Modules cache: clear `package.loaded['module']` during dev

**Neovim Patterns:**
- Commands: `vim.api.nvim_create_user_command()`
- Autocommands: Always use augroups with `clear = true`
- Keymaps: `vim.keymap.set()` not `vim.api.nvim_set_keymap()`
- UI: `vim.ui.input()` / `vim.ui.select()` / floating windows

## Current State

**Completed:**
- [x] Strategic planning & documentation review
- [x] Directory structure created
- [x] Source analysis (Continue = AI assistant with Chat/Edit/Autocomplete/Agent)
- [ ] Base structure (skeleton files)
- [ ] Core logic port
- [ ] Feature parity
- [ ] Polish & docs

**Active Phase:** Phase 0 - Initial setup

**Current Focus:** Creating plugin skeleton and analyzing Continue's architecture

**Next Tasks:**
1. Create init.lua with basic setup()
2. Inventory all Continue commands from package.json
3. Design LLM integration strategy (HTTP client for AI APIs)
4. Plan UI approach (floating windows vs buffers)

**Key Decisions Needed:**
- Which AI providers to support initially (OpenAI, Claude, local models?)
- Async strategy: plenary.async vs callback-based
- UI approach: How to replace Continue's WebView GUI

## Quick Links

When you need:
- **API translation** → `docs/API_MAPPING.md`
- **Copy-paste snippets** → `docs/QUICK_REFERENCE.md`
- **Deep reference** → `docs/PROJECT_KNOWLEDGE.md`
- **Progress check** → `docs/PORTING_CHECKLIST.md`

## Notes for LLMs

- **Tool preference**: Use Morph for file edits (it's installed)
- **Token awareness**: Reference docs are verbose; read selectively
- **Incremental**: Build one feature at a time, test frequently
- **Update this file**: Keep "Current State" section current
- **Keep the docs up-to-date**: Should anything change in design, etc.: update the relevant docs
- **Ask first**: If unclear, ask before assuming

---

*Last updated: 2025-10-26*
*Current phase: Phase 0 - Initial Setup & Analysis*

