# Porting Checklist

Use this document to track progress when porting a plugin to Neovim.

## Pre-Port Analysis

### Source Plugin Inventory
- [x] Plugin name: Continue
- [x] Source platform: [x] VSCode [ ] JetBrains
- [x] Repository URL: https://github.com/continuedev/continue
- [x] Version to port: 1.3.23
- [x] Documentation reviewed: [x] Yes [ ] No

### Feature Inventory

List all features/commands from the source plugin:

```
Command/Feature Name              | Priority | Neovim Equivalent           | Status | Notes
----------------------------------|----------|----------------------------|--------|------------------
CORE FEATURES:
Chat Interface                    | High     | Floating window + LLM API  | TODO   | Main feature
Inline Edit (Cmd+I)              | High     | Virtual text + diff        | TODO   | Core editing
Autocomplete (Tab)               | High     | nvim-cmp integration?      | TODO   | Complex
Agent/Task Automation            | Medium   | Custom automation          | TODO   | Advanced

COMMANDS (from package.json):
focusContinueInput (Cmd+L)       | High     | :ContinueChat              | TODO   | Open chat
focusContinueInputWithoutClear   | Medium   | :ContinueChatAppend        | TODO   | Append to chat
focusEdit (Cmd+I)                | High     | :ContinueEdit              | TODO   | Start edit mode
acceptDiff                       | High     | Accept edit keybind        | TODO   | Shift+Cmd+Enter
rejectDiff                       | High     | Reject edit keybind        | TODO   | Shift+Cmd+Backspace
applyCodeFromChat                | Medium   | Apply code snippet         | TODO   | From chat to buffer
newSession                       | Medium   | New chat session           | TODO   | Clear history
viewHistory                      | Low      | Show chat history          | TODO   | Nice to have
shareSession                     | Low      | Export chat as markdown    | TODO   | Optional
selectFilesAsContext             | Medium   | Add files to context       | TODO   | File picker
debugTerminal                    | Low      | Debug terminal output      | TODO   | Optional
toggleTabAutocomplete            | Medium   | Toggle autocomplete        | TODO   | Feature toggle
forceAutocomplete                | Low      | Manual trigger             | TODO   | Ctrl+Alt+Space
openConfigPage                   | Low      | Open config                | TODO   | Show settings
writeCommentsForCode             | Low      | AI comment generation      | TODO   | Nice to have
writeDocstringForCode            | Low      | AI docstring generation    | TODO   | Nice to have
fixCode                          | Medium   | AI code fix                | TODO   | Useful
optimizeCode                     | Low      | AI optimization            | TODO   | Optional
codebaseForceReIndex             | Low      | Rebuild codebase index     | TODO   | For @codebase
enterEnterpriseLicenseKey        | Low      | N/A                        | SKIP   | Enterprise only

CONFIGURATION:
telemetryEnabled                 | Low      | Optional telemetry         | TODO   | Privacy-friendly default
showInlineTip                    | Low      | Show inline tips           | TODO   | Optional
enableTabAutocomplete            | High     | Toggle autocomplete        | TODO   | Core setting
pauseTabAutocompleteOnBattery    | Low      | Battery detection          | SKIP   | Complex, optional
remoteConfigServer               | Low      | Remote config sync         | SKIP   | Not needed initially
```

### Dependencies Audit

Source plugin dependencies:

```
Dependency              | Purpose           | Neovim Alternative      | Notes
------------------------|-------------------|-------------------------|-------
Example: axios          | HTTP requests     | vim.loop.http or plenary| 
                        |                   |                         |
                        |                   |                         |
```

Required Neovim plugins:
- [ ] plenary.nvim (utilities, async) - Probably needed
- [ ] nui.nvim (UI components) - If rich UI needed
- [ ] nvim-treesitter (syntax awareness) - If parsing needed
- [ ] Other: ________________

### Complexity Assessment

**Lines of Code:**
- Source plugin: ~2000-3000 LOC (VSCode extension only, excluding core)
- Estimated Neovim plugin: ~1200-1800 LOC (40-60% of source)

**Complexity Rating:**
- [ ] Simple (1-5 commands, minimal state, <500 LOC)
- [ ] Medium (5-15 commands, some async, 500-1500 LOC)
- [x] Complex (15+ commands, heavy async, >1500 LOC)

**Major Challenges:**
1. LLM Integration - Need HTTP client for OpenAI/Anthropic/Ollama APIs with streaming support
2. UI/UX Translation - Continue uses React WebView, we need floating windows/buffers
3. Autocomplete Integration - Complex integration with Neovim's completion system
4. Async Patterns - Streaming LLM responses require careful async handling
5. State Management - Managing chat history, edit sessions, context

## Phase 1: Foundation ✓

### Setup
- [x] Create plugin directory structure
- [x] Set up Git repository (already exists)
- [ ] Create README.md with project info
- [x] Create LICENSE file (Apache 2.0, already exists)
- [x] Set up local dev environment

### Minimal Plugin
- [x] Create `lua/continue-nvim/init.lua`
- [x] Implement basic `setup()` function
- [x] Register test commands (ContinueChat, ContinueEdit, ContinueAgent)
- [ ] Verify plugin loads in Neovim
- [ ] Test hot reload workflow

**Blockers/Notes:**
```
(Document any issues encountered)
```

## Phase 2: Core Logic ⏸️

### Business Logic Extraction
- [ ] Identify platform-agnostic code in source
- [ ] Extract algorithms/utilities to separate modules
- [ ] Port data structures to Lua tables
- [ ] Port validation logic
- [ ] Port transformation logic

### Configuration System
- [ ] Define default configuration
- [ ] Implement `setup(opts)` with merging
- [ ] Document all config options
- [ ] Test config validation

**Files Created:**
- [ ] `lua/plugin-name/config.lua`
- [ ] `lua/plugin-name/utils.lua`
- [ ] Other: ________________

## Phase 3: Commands & Features ⏸️

### Command Porting

Track each command/feature:

```
Source Command          | Neovim Command        | Status | Test? | Notes
------------------------|----------------------|--------|-------|-------
Example: myExt.doThing  | MyPluginDoThing      | ✓ Done | ✓ Yes | Works!
                        |                      |        |       |
                        |                      |        |       |
                        |                      |        |       |
```

### Keybindings
- [ ] Define default keymaps (make opt-in via config)
- [ ] Document all keybindings in README
- [ ] Test keymap conflicts with popular plugins

### UI Elements

```
Source UI Element       | Neovim Implementation     | Status | Notes
------------------------|---------------------------|--------|-------
Example: Quick Pick     | vim.ui.select()           | ✓ Done | Built-in
Example: WebView Panel  | Floating window + buffer  | TODO   | Complex
                        |                           |        |
```

### Autocommands
- [ ] Create augroup with clear = true
- [ ] Port reactive behaviors as autocommands
- [ ] Document autocommand triggers
- [ ] Test autocommand cleanup

## Phase 4: Polish ⏸️

### Error Handling
- [ ] Wrap risky operations in pcall
- [ ] Provide user-friendly error messages
- [ ] Add debug logging (optional, disabled by default)
- [ ] Handle edge cases (empty buffers, invalid files, etc.)

### Performance
- [ ] Profile with `:profile start profile.log`
- [ ] Optimize hot paths
- [ ] Cache expensive computations
- [ ] Test with large files (if applicable)

### Documentation
- [ ] Create Vim help docs (`doc/plugin-name.txt`)
- [ ] Update README with:
  - [ ] Installation instructions (lazy.nvim, packer, etc.)
  - [ ] Configuration examples
  - [ ] Command reference
  - [ ] Screenshots/demos (if applicable)
- [ ] Add CHANGELOG.md
- [ ] Document known limitations vs source plugin

### Testing
- [ ] Write basic plenary tests
- [ ] Test in clean Neovim config
- [ ] Test with popular plugin managers
- [ ] Test on Linux / macOS / Windows (if applicable)

## Phase 5: Release 🚀

### Pre-Release
- [ ] Version number decided: ________________
- [ ] Tag release in Git
- [ ] Create GitHub release notes
- [ ] Update CHANGELOG.md

### Distribution
- [ ] Test installation via lazy.nvim
- [ ] Test installation via packer.nvim
- [ ] Submit to awesome-neovim list
- [ ] Consider LuaRocks packaging

### Community
- [ ] Post to r/neovim
- [ ] Share in Neovim Discord/Matrix
- [ ] Create demo video/GIF (optional but helpful)
- [ ] Monitor issues for feedback

---

## Lessons Learned

**What went well:**
- 

**What was challenging:**
- 

**What would you do differently:**
- 

**Tips for next port:**
- 

---

## Metrics

**Effort Tracking:**
- Start date: ________________
- End date: ________________
- Total hours: ________________
- Token usage (LLM): ~______K tokens

**Code Stats:**
- Source LOC: ________________
- Neovim LOC: ________________
- Reduction: ________________%

**Feature Parity:**
- Source features: _____ total
- Ported: _____ (____%)
- Skipped: _____ (reason: ________________)

---

*This checklist should be copied and filled out for each porting project.*
