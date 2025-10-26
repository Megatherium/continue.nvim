-- Continue.nvim - AI code assistant for Neovim
-- Port of the Continue VSCode extension

local M = {}

-- Plugin state
local state = {
  initialized = false,
  llm_client = nil,
}

-- Default configuration
M.config = {
  -- AI provider settings
  provider = {
    name = 'openai', -- 'openai', 'anthropic', 'ollama', etc.
    api_key = nil,   -- Set via env var or config
    model = 'gpt-4', -- Default model
    api_url = nil,   -- Optional custom API endpoint
  },

  -- Feature toggles
  features = {
    chat = true,
    edit = true,
    autocomplete = true,
    agent = true,
  },

  -- UI settings
  ui = {
    float_border = 'rounded',
    float_width = 0.8,  -- 80% of editor width
    float_height = 0.8, -- 80% of editor height
  },

  -- Keybindings (opt-in)
  keymaps = {
    enabled = false, -- Users should opt-in to default keymaps
    chat = '<leader>cc',
    edit = '<leader>ce',
    agent = '<leader>ca',
  },

  -- Logging
  log_level = 'info', -- 'debug', 'info', 'warn', 'error'
}

-- Setup function - called by user in their config
function M.setup(opts)
  opts = opts or {}

  -- Merge user config with defaults
  M.config = vim.tbl_deep_extend('force', M.config, opts)

  -- Validate configuration
  local ok, err = pcall(M._validate_config)
  if not ok then
    vim.notify('Continue.nvim: Invalid configuration - ' .. tostring(err), vim.log.levels.ERROR)
    return
  end

  -- Initialize components
  M._init_commands()
  M._init_keymaps()
  M._init_autocommands()

  -- Load feature modules
  if M.config.features.chat then
    require('continue-nvim.chat')
  end

  if M.config.features.edit then
    require('continue-nvim.edit')
  end

  if M.config.features.autocomplete then
    require('continue-nvim.autocomplete')
  end

  if M.config.features.agent then
    require('continue-nvim.agent')
  end

  state.initialized = true

  vim.notify('Continue.nvim initialized', vim.log.levels.INFO)
end

-- Validate configuration
function M._validate_config()
  -- Check if provider is supported
  local supported_providers = { 'openai', 'anthropic', 'ollama', 'custom' }
  local provider = M.config.provider.name

  if not vim.tbl_contains(supported_providers, provider) then
    error(string.format('Unsupported provider: %s (supported: %s)',
      provider, table.concat(supported_providers, ', ')))
  end

  -- Warn if API key is missing for cloud providers
  if (provider == 'openai' or provider == 'anthropic') and not M.config.provider.api_key then
    vim.notify('Continue.nvim: API key not configured. Set provider.api_key or use env var',
      vim.log.levels.WARN)
  end

  return true
end

-- Initialize user commands
function M._init_commands()
  -- Chat commands
  vim.api.nvim_create_user_command('ContinueChat', function(opts)
    require('continue-nvim.chat').open(opts.args)
  end, {
    nargs = '?',
    desc = 'Open Continue chat interface',
  })

  -- Edit command
  vim.api.nvim_create_user_command('ContinueEdit', function()
    require('continue-nvim.edit').start()
  end, {
    desc = 'Start inline AI edit',
  })

  -- Agent command
  vim.api.nvim_create_user_command('ContinueAgent', function(opts)
    require('continue-nvim.agent').start(opts.args)
  end, {
    nargs = '?',
    desc = 'Start Continue agent for task automation',
  })

  -- Config command
  vim.api.nvim_create_user_command('ContinueConfig', function()
    M.show_config()
  end, {
    desc = 'Show Continue.nvim configuration',
  })
end

-- Initialize keymaps (if enabled)
function M._init_keymaps()
  if not M.config.keymaps.enabled then
    return
  end

  local keymaps = M.config.keymaps

  if keymaps.chat then
    vim.keymap.set('n', keymaps.chat, ':ContinueChat<CR>', {
      desc = 'Open Continue chat',
      silent = true,
    })
  end

  if keymaps.edit then
    vim.keymap.set({ 'n', 'v' }, keymaps.edit, ':ContinueEdit<CR>', {
      desc = 'Start Continue edit',
      silent = true,
    })
  end

  if keymaps.agent then
    vim.keymap.set('n', keymaps.agent, ':ContinueAgent<CR>', {
      desc = 'Start Continue agent',
      silent = true,
    })
  end
end

-- Initialize autocommands
function M._init_autocommands()
  local augroup = vim.api.nvim_create_augroup('ContinueNvim', { clear = true })

  -- Example: Clean up on exit
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = augroup,
    callback = function()
      M.cleanup()
    end,
    desc = 'Continue.nvim cleanup on exit',
  })
end

-- Show current configuration
function M.show_config()
  local config_str = vim.inspect(M.config)
  local buf = vim.api.nvim_create_buf(false, true)
  local lines = vim.split(config_str, '\n')

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'filetype', 'lua')
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)

  -- Open in floating window
  local width = math.floor(vim.o.columns * 0.6)
  local height = math.floor(vim.o.lines * 0.6)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = M.config.ui.float_border,
    title = ' Continue.nvim Configuration ',
    title_pos = 'center',
  })

  -- Close on q or Esc
  vim.keymap.set('n', 'q', ':close<CR>', { buffer = buf, silent = true })
  vim.keymap.set('n', '<Esc>', ':close<CR>', { buffer = buf, silent = true })
end

-- Cleanup resources
function M.cleanup()
  -- Close any open floating windows
  -- Cancel any pending LLM requests
  -- Save any session data
  state.initialized = false
end

-- Check if plugin is ready
function M.is_ready()
  return state.initialized
end

return M