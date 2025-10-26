# Implementation Checklist: Continue.nvim

Progress tracker for building the Continue HTTP client for Neovim.

## Phase 0: Architecture & Documentation ✅

- [x] Architecture decision (HTTP client vs full port)
- [x] Analyze Continue CLI HTTP protocol
- [x] Update CLAUDE.md with new architecture
- [x] Rewrite PROJECT_KNOWLEDGE.md for HTTP client
- [x] Rewrite API_MAPPING.md for HTTP protocol
- [x] Rewrite QUICK_REFERENCE.md with client patterns
- [x] Create implementation checklist
- [x] Restructure lua/ directory

## Phase 1: Core Infrastructure ⏳

### 1.1: HTTP Client (`lua/continue/utils/http.lua`)
- [ ] Implement GET request (curl-based or vim.loop)
- [ ] Implement POST request
- [ ] Error handling and retries
- [ ] Timeout handling
- [ ] Test with mock HTTP server

### 1.2: JSON Handling (`lua/continue/utils/json.lua`)
- [ ] Verify Neovim version is 0.10+ on startup
- [ ] Use `vim.json` for all encode/decode operations
- [ ] Test encode/decode with sample data

### 1.3: Process Manager (`lua/continue/process.lua`)
- [ ] `start()` - Spawn `cn serve` with jobstart
- [ ] `stop()` - Graceful shutdown (POST /exit + force kill)
- [ ] `wait_for_ready()` - Health check polling
- [ ] `status()` - Get current process state
- [ ] Auto-cleanup on VimLeavePre
- [ ] Test process lifecycle

### 1.4: State Management (`lua/continue/state.lua`)
- [ ] Central state store
- [ ] Getters/setters for process, client, UI state
- [ ] State change notifications (optional)

## Phase 2: HTTP Client Logic ⏳

### 2.1: Client Core (`lua/continue/client.lua`)
- [ ] `start_polling()` - Timer-based state polling (500ms)
- [ ] `stop_polling()` - Stop timer
- [ ] `get_state()` - GET /state
- [ ] `send_message()` - POST /message
- [ ] `send_permission()` - POST /permission
- [ ] `pause()` - POST /pause
- [ ] `get_diff()` - GET /diff
- [ ] `exit()` - POST /exit
- [ ] Test with running `cn serve`

### 2.2: State Diff Logic
- [ ] Compare old/new chatHistory
- [ ] Detect new messages (append)
- [ ] Detect removed messages (interrupted)
- [ ] Detect streaming updates
- [ ] Return structured diff ({ type, data })

## Phase 3: UI Implementation ⏳

### 3.1: Chat Buffer (`lua/continue/ui/chat.lua`)
- [ ] `create_buffer()` - Create scratch buffer
- [ ] `render_message(msg)` - Render single message
- [ ] `update_from_state(state)` - Process state diff
- [ ] `update_streaming_message(msg)` - Handle streaming
- [ ] `setup_keymaps()` - Buffer-local keymaps
  - [ ] `<CR>` in insert mode - Send message
  - [ ] `<Esc>` in normal mode - Pause agent
  - [ ] `q` - Close chat
- [ ] Syntax highlighting (markdown)
- [ ] Auto-scroll to bottom

### 3.2: Floating Window (`lua/continue/ui/floating.lua`)
- [ ] `open(bufnr)` - Open floating window
- [ ] `close()` - Close window
- [ ] `resize()` - Handle terminal resize
- [ ] Border styling
- [ ] Window positioning (center, custom)

### 3.3: Permission Prompts
- [ ] Detect `pendingPermission` in state
- [ ] Show vim.ui.select with Yes/No
- [ ] Send response to POST /permission
- [ ] Handle approval/rejection

### 3.4: Status Line Integration (Optional)
- [ ] Show processing status
- [ ] Show queue length
- [ ] Show connection status

## Phase 4: Commands & Configuration ⏳

### 4.1: User Commands (`lua/continue/commands.lua`)
- [ ] `:Continue [message]` - Open chat or send message
- [ ] `:ContinueStart` - Start cn serve
- [ ] `:ContinueStop` - Stop cn serve
- [ ] `:ContinuePause` - Pause current execution
- [ ] `:ContinueDiff` - Show git diff
- [ ] `:ContinueHealth` - Health check
- [ ] `:ContinueLog` - Show logs

### 4.2: Configuration (`lua/continue/config.lua`)
- [ ] Default config schema
- [ ] `setup(opts)` - Merge user config
- [ ] Port configuration
- [ ] Timeout configuration
- [ ] Auto-start toggle
- [ ] Custom cn binary path
- [ ] Continue config path

### 4.3: Plugin Entry Point (`lua/continue/init.lua`)
- [ ] `setup(opts)` - Main entry point
- [ ] Initialize all modules
- [ ] Register commands
- [ ] Auto-start if configured
- [ ] Export public API

## Phase 5: Polish & UX ⏳

### 5.1: Error Handling
- [ ] Graceful degradation if cn serve not found
- [ ] User-friendly error messages
- [ ] Fallback behavior on HTTP errors
- [ ] Notify user on connection loss
- [ ] Retry logic for transient failures

### 5.2: Logging & Debugging
- [ ] Optional debug logging to file
- [ ] Log HTTP requests/responses
- [ ] Log process lifecycle events
- [ ] Health check command
- [ ] State inspection command

### 5.3: Documentation
- [ ] README.md with installation instructions
- [ ] Usage examples
- [ ] Configuration examples
- [ ] Troubleshooting guide
- [ ] Vim help docs (`:help continue.nvim`)

### 5.4: User Experience
- [ ] Loading indicators
- [ ] Progress notifications
- [ ] Smooth streaming updates
- [ ] Clear visual feedback
- [ ] Keyboard shortcuts documentation

## Phase 6: Testing & Validation ⏳

### 6.1: Manual Testing
- [ ] Test process spawning
- [ ] Test HTTP polling
- [ ] Test message sending
- [ ] Test permission flow
- [ ] Test interruption (pause)
- [ ] Test git diff display
- [ ] Test graceful shutdown
- [ ] Test auto-cleanup on exit

### 6.2: Edge Cases
- [ ] cn serve not installed
- [ ] Port already in use
- [ ] Server crashes mid-conversation
- [ ] Network timeout
- [ ] Malformed JSON responses
- [ ] Empty state/history
- [ ] Very long messages
- [ ] Rapid message sending

### 6.3: Integration Testing
- [ ] Test with real Continue backend
- [ ] Test with multiple LLM providers
- [ ] Test tool execution
- [ ] Test MCP server integration
- [ ] Test session persistence

### 6.4: Automated Tests (Optional)
- [ ] Unit tests with plenary.nvim
- [ ] Mock HTTP server for testing
- [ ] CI/CD setup (GitHub Actions)

## Phase 7: Release Preparation ⏳

### 7.1: Documentation
- [ ] Complete README.md
- [ ] Add screenshots/GIFs
- [ ] Document dependencies
- [ ] Write migration guide (if applicable)
- [ ] Create CHANGELOG.md

### 7.2: Package Preparation
- [ ] Test with lazy.nvim
- [ ] Test with packer.nvim
- [ ] Test with rocks.nvim
- [ ] Verify plugin/ directory auto-loading
- [ ] Check all module paths

### 7.3: Repository Setup
- [ ] LICENSE file
- [ ] .gitignore
- [ ] Issue templates
- [ ] Pull request template
- [ ] Contributing guidelines

### 7.4: Release
- [ ] Tag v0.1.0
- [ ] Create GitHub release
- [ ] Announce on r/neovim
- [ ] Add to awesome-neovim list

---

## Current Status

**Active Phase**: Phase 0 - Architecture & Documentation ✅
**Next Phase**: Phase 1 - Core Infrastructure
**Completion**: ~8%

**Next Steps**:
1. Create lua/ directory structure
2. Implement HTTP client (curl-based for simplicity)
3. Implement process manager
4. Test cn serve spawning

---

## Effort Estimates

| Phase | Estimated Tokens | Est. Time |
|-------|-----------------|-----------|
| Phase 0 | ~2K | ✅ Done |
| Phase 1 | ~2-3K | 1-2 hours |
| Phase 2 | ~2K | 1 hour |
| Phase 3 | ~3-4K | 2-3 hours |
| Phase 4 | ~1-2K | 1 hour |
| Phase 5 | ~1K | 1 hour |
| Phase 6 | ~1K | 2-3 hours |
| Phase 7 | ~1K | 1 hour |
| **Total** | **~13-16K** | **9-13 hours** |

**Original estimate** (full port): 40-70K tokens
**Savings**: ~75-85% reduction in effort

---

## Dependencies

**Required**:
- Neovim 0.10+ (for `vim.loop`, `vim.json`, floating windows)
- `cn` (Continue CLI) installed: `npm install -g @continuedev/cli`
- `curl` (for HTTP client) OR use vim.loop TCP

**Optional**:
- Snacks.nvim (better terminal integration)
- nvim-notify (better notifications)
- plenary.nvim (testing framework)

---

*Update this file as you complete tasks. Check off items with `[x]`.*