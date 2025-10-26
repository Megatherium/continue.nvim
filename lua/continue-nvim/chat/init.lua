-- Continue.nvim - Chat module
-- AI chat interface for asking questions and clarifying code

local M = {}

function M.open(initial_message)
  -- TODO: Implement chat window
  vim.notify('Continue Chat: Not yet implemented', vim.log.levels.WARN)
end

function M.send_message(message)
  -- TODO: Send message to LLM and stream response
end

function M.add_context(range)
  -- TODO: Add code selection to chat context
end

return M
