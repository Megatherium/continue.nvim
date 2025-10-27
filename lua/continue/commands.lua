-- User commands

local M = {}

local config = nil
local ensure_deps = nil
local ensure_started = nil

function M.setup(user_config, dependency_checker, lazy_start_fn)
  config = user_config
  ensure_deps = dependency_checker
  ensure_started = lazy_start_fn

  -- :Continue [message] - Open chat or send message
  vim.api.nvim_create_user_command('Continue', function(opts)
    if not ensure_deps() then
      return
    end

    -- Lazy start server on first use
    if not ensure_started() then
      vim.notify('Failed to start Continue server', vim.log.levels.ERROR)
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
      client.send_message(status.port, opts.args)
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
    if not ensure_started() then
      vim.notify('Failed to start Continue server', vim.log.levels.ERROR)
      return
    end

    local process = require('continue.process')
    local client = require('continue.client')
    local status = process.status()

    client.pause(status.port)
  end, { desc = 'Pause Continue agent execution' })

  -- :ContinueStatus - Show status
  vim.api.nvim_create_user_command('ContinueStatus', function()
    local status = require('continue').status()
    print(vim.inspect(status))
  end, { desc = 'Show Continue status' })

  -- :ContinueDiff - Show git diff
  vim.api.nvim_create_user_command('ContinueDiff', function()
    if not ensure_started() then
      vim.notify('Failed to start Continue server', vim.log.levels.ERROR)
      return
    end

    local process = require('continue.process')
    local client = require('continue.client')
    local status = process.status()

    client.get_diff(status.port, function(err, diff)
      if err then
        vim.notify('Failed to get diff: ' .. err, vim.log.levels.ERROR)
        return
      end

      -- Display diff in a new buffer
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(diff, '\n'))
      vim.api.nvim_buf_set_option(bufnr, 'filetype', 'diff')
      vim.api.nvim_buf_set_option(bufnr, 'buftype', 'nofile')
      vim.api.nvim_buf_set_name(bufnr, 'Continue Diff')

      -- Open in split
      vim.cmd('split')
      vim.api.nvim_win_set_buf(0, bufnr)
    end)
  end, { desc = 'Show git diff from Continue server' })

  -- :ContinueHealth - Health check
  vim.api.nvim_create_user_command('ContinueHealth', function()
    local health_results = {}

    -- Check dependencies
    table.insert(health_results, '=== Continue.nvim Health Check ===')
    table.insert(health_results, '')

    -- Check Neovim version
    local nvim_version = vim.version()
    if vim.fn.has('nvim-0.10') == 1 then
      table.insert(health_results, '✓ Neovim version: ' .. nvim_version.major .. '.' .. nvim_version.minor .. ' (OK)')
    else
      table.insert(health_results, '✗ Neovim version: ' .. nvim_version.major .. '.' .. nvim_version.minor .. ' (need 0.10+)')
    end

    -- Check Node.js
    local node_version = vim.fn.system('node --version')
    if vim.v.shell_error == 0 then
      table.insert(health_results, '✓ Node.js: ' .. node_version:gsub('\n', ''))
    else
      table.insert(health_results, '✗ Node.js: not found')
    end

    -- Check cn binary
    local cn_path = vim.fn.exepath(config.cn_bin or 'cn')
    if cn_path ~= '' then
      local cn_version = vim.fn.system((config.cn_bin or 'cn') .. ' --version')
      if vim.v.shell_error == 0 then
        table.insert(health_results, '✓ Continue CLI: ' .. cn_version:gsub('\n', '') .. ' (' .. cn_path .. ')')
      else
        table.insert(health_results, '✓ Continue CLI: installed at ' .. cn_path)
      end
    else
      table.insert(health_results, '✗ Continue CLI: not found (run: npm install -g @continuedev/cli)')
    end

    -- Check curl
    local http = require('continue.utils.http')
    if http.has_curl() then
      table.insert(health_results, '✓ curl: available')
    else
      table.insert(health_results, '✗ curl: not found')
    end

    -- Check server status
    table.insert(health_results, '')
    local process = require('continue.process')
    local process_status = process.status()

    if process_status.running then
      table.insert(health_results, '✓ Server: running on port ' .. process_status.port)

      -- Synchronous health check using curl
      local health_check_cmd = 'curl -s -m 2 http://localhost:' .. process_status.port .. '/state 2>&1'
      local health_output = vim.fn.system(health_check_cmd)
      
      if vim.v.shell_error == 0 and health_output:match('"isProcessing"') then
        table.insert(health_results, '✓ Server health: OK')
      else
        table.insert(health_results, '✗ Server health: unreachable or unhealthy')
      end
    else
      table.insert(health_results, '○ Server: not running')
    end

    -- Display all results at once
    vim.notify(table.concat(health_results, '\n'), vim.log.levels.INFO)
  end, { desc = 'Check Continue.nvim health' })

  -- :ContinueExport - Export chat to markdown
  vim.api.nvim_create_user_command('ContinueExport', function(opts)
    if not ensure_started() then
      vim.notify('Failed to start Continue server', vim.log.levels.ERROR)
      return
    end

    local client = require('continue.client')
    local export = require('continue.export')
    local status = client.status()
    
    if not status.has_state then
      vim.notify('No chat history to export', vim.log.levels.WARN)
      return
    end
    
    -- Get chat history from client state
    local process = require('continue.process')
    local proc_status = process.status()
    
    -- Fetch current state to export
    local http = require('continue.utils.http')
    http.get(string.format('http://localhost:%d/state', proc_status.port), function(err, response)
      if err then
        vim.notify('Failed to fetch state: ' .. err, vim.log.levels.ERROR)
        return
      end
      
      local ok, server_state = pcall(vim.json.decode, response.body)
      if not ok or not server_state.chatHistory then
        vim.notify('Failed to parse chat history', vim.log.levels.ERROR)
        return
      end
      
      -- Determine output path
      local filepath
      if opts.args and opts.args ~= '' then
        filepath = opts.args
      else
        -- Auto-generate filename
        local auto_path, err = export.auto_export(server_state.chatHistory)
        if not auto_path then
          vim.notify('Export failed: ' .. (err or 'unknown error'), vim.log.levels.ERROR)
          return
        end
        filepath = auto_path
      end
      
      -- Export to file
      local success, export_err = export.to_file(server_state.chatHistory, filepath)
      if not success then
        vim.notify('Export failed: ' .. (export_err or 'unknown error'), vim.log.levels.ERROR)
        return
      end
      
      vim.notify(string.format('Exported %d messages to: %s', 
        #server_state.chatHistory, filepath), vim.log.levels.INFO)
      
      -- Offer to open the file
      vim.ui.select({'Yes', 'No'}, {
        prompt = 'Open exported file?'
      }, function(choice)
        if choice == 'Yes' then
          vim.cmd('edit ' .. vim.fn.fnameescape(filepath))
        end
      end)
    end)
  end, { 
    nargs = '?', 
    desc = 'Export chat history to markdown',
    complete = 'file'
  })

  -- TODO: :ContinueLog - Show logs (if we add logging to file)
end

return M