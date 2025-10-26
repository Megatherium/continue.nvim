-- Process manager for cn serve

local M = {}

local state = {
  job_id = nil,
  port = 8000,
  running = false,
}

function M.start(config)
  -- TODO: Implement cn serve spawning
  -- See docs/QUICK_REFERENCE.md for implementation
  vim.notify('Continue: Process manager not yet implemented', vim.log.levels.WARN)
end

function M.stop()
  -- TODO: Implement graceful shutdown
end

function M.status()
  return state
end

return M