-- Continue.nvim - LLM client utilities
-- HTTP client for interacting with AI providers

local M = {}

-- Make HTTP request to LLM provider
function M.request(provider, prompt, opts)
  opts = opts or {}

  -- TODO: Implement HTTP client using vim.loop or plenary
  -- Different providers have different API formats:
  -- - OpenAI: Chat Completions API
  -- - Anthropic: Messages API
  -- - Ollama: Generate API (local)

  return {
    success = false,
    error = 'Not implemented yet'
  }
end

-- Stream response from LLM (for real-time display)
function M.stream(provider, prompt, callback)
  -- TODO: Implement streaming using Server-Sent Events (SSE)
  -- Call callback(chunk) for each response chunk
end

return M
