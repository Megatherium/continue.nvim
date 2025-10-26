-- Continue.nvim - Configuration module
-- Configuration schema and validation

local M = {}

-- Configuration schema (for reference/validation)
M.schema = {
  provider = {
    type = 'table',
    fields = {
      name = { type = 'string', required = true },
      api_key = { type = 'string', required = false },
      model = { type = 'string', required = true },
      api_url = { type = 'string', required = false },
    }
  },
  features = {
    type = 'table',
    fields = {
      chat = { type = 'boolean', default = true },
      edit = { type = 'boolean', default = true },
      autocomplete = { type = 'boolean', default = true },
      agent = { type = 'boolean', default = true },
    }
  },
  ui = {
    type = 'table',
    fields = {
      float_border = { type = 'string', default = 'rounded' },
      float_width = { type = 'number', default = 0.8 },
      float_height = { type = 'number', default = 0.8 },
    }
  },
}

-- Load API key from environment
function M.get_api_key(provider_name)
  local env_vars = {
    openai = 'OPENAI_API_KEY',
    anthropic = 'ANTHROPIC_API_KEY',
  }

  local env_var = env_vars[provider_name]
  if env_var then
    return os.getenv(env_var)
  end

  return nil
end

return M
