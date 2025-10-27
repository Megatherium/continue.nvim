-- Continue.nvim: HTTP client for Continue CLI
-- Main entry point

local M = {}

M.config = {
  port = 8000,
  port_range = { 8000, 8010 },
  timeout = 300, -- seconds
  auto_start = false, -- DEPRECATED: server now starts lazily on first command
  auto_find_port = true,
  cn_bin = 'cn', -- path to cn binary
  continue_config = nil, -- path to Continue config (optional)
}

-- Check if dependencies are installed
-- @return boolean - true if all dependencies available
local function check_dependencies()
  -- Check if cn exists
  local cn_path = vim.fn.exepath(M.config.cn_bin)
  if cn_path == '' then
    vim.notify(
      'Continue.nvim requires the Continue CLI.\n' .. 'Install: npm install -g @continuedev/cli',
      vim.log.levels.ERROR
    )
    return false
  end

  -- Check Node version
  local node_version = vim.fn.system('node --version')
  if vim.v.shell_error ~= 0 then
    vim.notify('Node.js not found. Continue CLI requires Node.js 18+', vim.log.levels.ERROR)
    return false
  end

  local major = tonumber(node_version:match('v(%d+)'))
  if major and major < 18 then
    vim.notify(
      string.format('Continue requires Node.js 18+, found: %s', node_version:gsub('\n', '')),
      vim.log.levels.ERROR
    )
    return false
  end

  -- Check cn version (informational)
  local cn_version = vim.fn.system(M.config.cn_bin .. ' --version')
  if vim.v.shell_error == 0 then
    vim.notify(
      string.format('Using Continue CLI: %s', cn_version:gsub('\n', '')),
      vim.log.levels.INFO
    )
  end

  -- Check Neovim version
  if vim.fn.has('nvim-0.10') ~= 1 then
    vim.notify('Continue.nvim requires Neovim 0.10+', vim.log.levels.ERROR)
    return false
  end

  return true
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})

  -- Check dependencies on first use, not on startup
  -- This is deferred until user actually tries to use Continue
  local deps_checked = false

  local function ensure_dependencies()
    if not deps_checked then
      deps_checked = true
      if not check_dependencies() then
        vim.notify('Continue.nvim: Dependency check failed, plugin disabled', vim.log.levels.WARN)
        return false
      end
    end
    return true
  end

  -- Lazy start helper: starts server if not running
  -- @return boolean - true if server is running or was started successfully
  local function ensure_started()
    local process = require('continue.process')
    local status = process.status()
    
    if status.running then
      return true
    end
    
    -- Start server on first use
    vim.notify('Starting Continue server...', vim.log.levels.INFO)
    return process.start(M.config)
  end

  -- Register commands (pass lazy start helper)
  require('continue.commands').setup(M.config, ensure_dependencies, ensure_started)

  -- Setup auto-cleanup on exit
  local augroup = vim.api.nvim_create_augroup('Continue', { clear = true })
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = augroup,
    callback = function()
      require('continue.process').stop()
      require('continue.client').stop_polling()
    end,
  })
end

-- Public API
M.start = function()
  require('continue.process').start(M.config)
end

M.stop = function()
  require('continue.process').stop()
end

M.status = function()
  local process_status = require('continue.process').status()
  local client_status = require('continue.client').status()

  return {
    process = process_status,
    client = client_status,
    config = M.config,
  }
end

return M