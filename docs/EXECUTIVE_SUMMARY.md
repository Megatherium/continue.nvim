# Executive Summary: Porting to Neovim

**TL;DR: Port from the VSCode extension. It'll cost ~50% fewer tokens and be less painful.**

## The Question

You have two existing plugins:
1. **JetBrains** (Kotlin)
2. **VSCode** (TypeScript)

Which one should you port to **Neovim** (Lua)?

## The Answer

**Port from VSCode.** Here's why:

### Cost Comparison

| Source | Estimated Token Cost | Relative Difficulty |
|--------|---------------------|---------------------|
| **VSCode (TypeScript)** | **40-70K tokens** | **1.0x** (baseline) |
| JetBrains (Kotlin) | 80-120K tokens | 2.0x (double!) |

### Why VSCode Wins

**1. Language & Paradigm Alignment**
- TypeScript → Lua: Natural translation
- Kotlin → Lua: Fighting OOP abstractions

**2. API Simplicity**
- VSCode: ~200-300 APIs, well-documented
- JetBrains: 1000+ APIs, heavily abstracted (PSI, VFS, etc.)

**3. Code Style Match**
- VSCode: Event-driven, functional patterns
- JetBrains: Heavy OOP, enterprise patterns
- Neovim: Functional, procedural Lua

**4. Training Data**
- More TypeScript/VSCode examples in LLM training
- Better pattern recognition for common idioms

**5. Boilerplate Reduction**
- TypeScript → Lua: ~30-40% LOC reduction
- Kotlin → Lua: ~50-60% LOC reduction (but more work to get there)

## The Catches

### VSCode Challenges
- May rely on Node.js ecosystem (need pure Lua alternatives)
- WebViews don't exist in Neovim (need creative floating window solutions)

### JetBrains Challenges  
- PSI tree manipulation doesn't map cleanly (Tree-sitter is less powerful)
- Threading model is completely different (single-threaded Lua)
- Gradle/build complexity obscures actual logic

## Recommended Workflow

1. **Start with VSCode extension** as source
2. **Inventory features** using PORTING_CHECKLIST.md
3. **Map APIs** using API_MAPPING.md reference
4. **Extract business logic** (platform-agnostic code)
5. **Build incrementally** - one command at a time
6. **Test constantly** - hot reload is your friend

## Key Files Created

1. **PROJECT_KNOWLEDGE.md** - Architecture, pain points, best practices
2. **API_MAPPING.md** - VSCode/JetBrains → Neovim API translations
3. **PORTING_CHECKLIST.md** - Step-by-step tracking tool

## Quick Start

```bash
# 1. Analyze the VSCode extension
cat package.json  # Commands, config, activation events
cat src/extension.ts  # Entry point

# 2. Create Neovim structure
mkdir -p lua/your-plugin
touch lua/your-plugin/init.lua

# 3. Implement basic setup
cat > lua/your-plugin/init.lua << 'EOF'
local M = {}

M.config = {
  -- defaults here
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})
  -- TODO: port commands
end

return M
EOF

# 4. Test it loads
nvim -c "lua require('your-plugin').setup()"
```

## Next Steps

1. Choose the VSCode extension as your source
2. Fill out the "Feature Inventory" section in PORTING_CHECKLIST.md
3. Start with the simplest command/feature first
4. Build up incrementally

## When to Reconsider JetBrains

Only port from JetBrains if:
- The VSCode extension is abandoned/broken
- JetBrains has significantly more features you need
- You're willing to spend 2x the effort
- You need its PSI-level code intelligence (which won't fully port anyway)

## The Bottom Line

**For humans**: VSCode is less work and less painful.  
**For LLMs**: VSCode costs ~50% fewer tokens and has better pattern recognition.

It's a clear win-win.

---

**Questions?** Read PROJECT_KNOWLEDGE.md for deep dive.
