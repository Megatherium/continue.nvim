-- Minimal init for testing Continue.nvim
-- Run with: nvim --clean -u tests/minimal_init.lua

-- Add current directory to runtimepath
local root = vim.fn.fnamemodify(vim.fn.getcwd(), ':p')
vim.opt.runtimepath:append(root)

-- Set up Continue.nvim
local ok, continue = pcall(require, 'continue-nvim')
if not ok then
  print('Failed to load continue-nvim: ' .. tostring(continue))
  return
end

-- Test basic setup
continue.setup({
  provider = {
    name = 'openai',
    model = 'gpt-4',
  },
  features = {
    chat = true,
    edit = true,
    autocomplete = false,  -- Disable for testing
    agent = false,
  },
})

-- Print success message
print('Continue.nvim loaded successfully!')
print('Try: :ContinueConfig to see configuration')
print('Try: :ContinueChat to test chat (will show not implemented)')
