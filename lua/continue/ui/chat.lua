-- Chat UI

local M = {}

function M.open()
  -- TODO: Implement chat buffer UI
  -- See docs/QUICK_REFERENCE.md for implementation
  vim.notify('Continue: Chat UI not yet implemented', vim.log.levels.WARN)
end

function M.render_message(bufnr, msg)
  -- TODO: Implement message rendering
end

function M.update_from_state(state)
  -- TODO: Handle state updates
end

return M