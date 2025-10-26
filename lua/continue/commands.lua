-- User commands

local M = {}

function M.setup()
  vim.api.nvim_create_user_command('Continue', function(opts)
    vim.notify('Continue: Commands not yet implemented', vim.log.levels.WARN)
    -- TODO: Implement command handler
  end, {
    nargs = '*',
    desc = 'Continue AI assistant',
  })

  -- TODO: Add more commands (ContinueStart, ContinueStop, etc.)
end

return M