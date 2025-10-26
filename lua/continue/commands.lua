-- User commands

local M = {}

local config = nil
local ensure_deps = nil

function M.setup(user_config, dependency_checker)
  config = user_config
  ensure_deps = dependency_checker

  -- :Continue [message] - Open chat or send message
  vim.api.nvim_create_user_command('Continue', function(opts)
    if not ensure_deps() then
      return
    end

    if opts.args == '' then
      -- Open chat UI
      require('continue.ui.chat').open()
    else
      -- Send message directly
      local process = require('continue.process')
      local client = require('continue.client')
      local status = process.status()

      if not status.running then
        vim.notify('Starting Continue server...', vim.log.levels.INFO)
        process.start(config)
        -- Wait a bit for server to start before sending message
        vim.defer_fn(function()
          client.send_message(status.port or config.port, opts.args)
        end, 2000)
      else
        client.send_message(status.port, opts.args)
      end
    end
  end, {
    nargs = '*',
    desc = 'Continue AI assistant - open chat or send message',
  })

  -- :ContinueStart - Start cn serve
  vim.api.nvim_create_user_command('ContinueStart', function()
    if not ensure_deps() then
      return
    end
    require('continue.process').start(config)
  end, { desc = 'Start Continue server' })

  -- :ContinueStop - Stop cn serve
  vim.api.nvim_create_user_command('ContinueStop', function()
    require('continue.process').stop()
    require('continue.client').stop_polling()
  end, { desc = 'Stop Continue server' })

  -- :ContinuePause - Pause agent execution
  vim.api.nvim_create_user_command('ContinuePause', function()
    local process = require('continue.process')
    local client = require('continue.client')
    local status = process.status()

    if not status.running then
      vim.notify('Continue server not running', vim.log.levels.WARN)
      return
    end

    client.pause(status.port)
  end, { desc = 'Pause Continue agent execution' })

  -- :ContinueStatus - Show status
  vim.api.nvim_create_user_command('ContinueStatus', function()
    local status = require('continue').status()
    print(vim.inspect(status))
  end, { desc = 'Show Continue status' })

  -- TODO: :ContinueDiff - Show git diff
  -- TODO: :ContinueHealth - Health check
  -- TODO: :ContinueLog - Show logs
end

return M
