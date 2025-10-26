-- Continue.nvim: HTTP client for Continue CLI
-- Main entry point

local M = {}

M.config = {
  port = 8000,
  timeout = 300, -- seconds
  auto_start = true,
  cn_bin = 'cn', -- path to cn binary
  continue_config = nil, -- path to Continue config (optional)
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})

  -- Auto-start cn serve if configured
  if M.config.auto_start then
    require('continue.process').start(M.config)
  end

  -- Register commands
  require('continue.commands').setup()

  -- Setup auto-cleanup
  local augroup = vim.api.nvim_create_augroup('Continue', { clear = true })
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = augroup,
    callback = function()
      require('continue.process').stop()
    end,
  })
end

return M