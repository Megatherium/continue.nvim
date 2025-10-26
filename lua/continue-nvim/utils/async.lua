-- Continue.nvim - Async utilities
-- Helper functions for asynchronous operations

local M = {}

-- Wrap callback-based function for easier use
function M.wrap(fn, argc)
  -- TODO: Implement async wrapper (or use plenary.async)
  return fn
end

-- Run function on next event loop iteration
function M.defer(fn)
  vim.schedule(fn)
end

-- Simple promise-like pattern for Lua
function M.promise(executor)
  local callbacks = { success = {}, error = {} }

  local function resolve(value)
    for _, cb in ipairs(callbacks.success) do
      cb(value)
    end
  end

  local function reject(err)
    for _, cb in ipairs(callbacks.error) do
      cb(err)
    end
  end

  executor(resolve, reject)

  return {
    on_success = function(cb)
      table.insert(callbacks.success, cb)
    end,
    on_error = function(cb)
      table.insert(callbacks.error, cb)
    end,
  }
end

return M
