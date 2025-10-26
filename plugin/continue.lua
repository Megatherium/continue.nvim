-- plugin/continue.lua
-- Auto-loaded by Neovim when plugin loads
--
-- This file is executed automatically when Neovim starts.
-- It serves as the entry point for the plugin but does NOT
-- load heavy modules until the user explicitly calls setup()
-- or uses a command (lazy loading pattern).

-- Prevent loading twice
if vim.g.loaded_continue then
  return
end
vim.g.loaded_continue = 1

-- Check minimum Neovim version
if vim.fn.has('nvim-0.10') ~= 1 then
  vim.notify(
    'continue.nvim requires Neovim 0.10 or later',
    vim.log.levels.ERROR
  )
  return
end

-- Plugin is ready to be configured via require('continue').setup()
-- No heavy initialization here - that happens in lua/continue/init.lua
