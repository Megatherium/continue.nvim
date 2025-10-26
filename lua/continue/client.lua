-- HTTP client for Continue server state management

local M = {}

local state = {
  timer = nil,
  polling = false,
  last_state = nil,
  port = nil,
  poll_interval = 500,  -- Current polling interval in ms
}

-- Polling interval constants
local POLL_INTERVAL_ACTIVE = 100  -- 100ms when processing (responsive)
local POLL_INTERVAL_IDLE = 1000   -- 1s when idle (efficient)
local POLL_INTERVAL_DEFAULT = 500 -- 500ms default

-- Start polling the server for state updates
-- @param port number - Port number where cn serve is running
-- @param callback function(state) - Optional callback for state updates
function M.start_polling(port, callback)
  if state.polling then
    vim.notify('Already polling Continue server', vim.log.levels.WARN)
    return
  end

  state.port = port
  state.polling = true
  state.timer = vim.loop.new_timer()

  local http = require('continue.utils.http')
  local ui = require('continue.ui.chat')

  local function poll()
    http.get(string.format('http://localhost:%d/state', port), function(err, response)
      if err then
        -- Server might be starting up or crashed
        -- TODO: Add reconnection logic
        return
      end

      local ok, server_state = pcall(vim.json.decode, response.body)
      if not ok then
        vim.notify('Failed to parse server state', vim.log.levels.ERROR)
        return
      end

      -- Update UI with new state
      ui.update_from_state(server_state)

      -- Call user callback if provided
      if callback then
        callback(server_state)
      end

      -- Dynamic interval adjustment based on activity
      local new_interval = M.calculate_poll_interval(server_state)
      if new_interval ~= state.poll_interval then
        state.poll_interval = new_interval
        -- Restart timer with new interval
        if state.timer then
          state.timer:stop()
          state.timer:start(0, new_interval, vim.schedule_wrap(poll))
        end
      end

      state.last_state = server_state
    end)
  end

  -- Start polling at dynamic intervals
  state.timer:start(0, POLL_INTERVAL_DEFAULT, vim.schedule_wrap(poll))

  vim.notify('Started polling Continue server on port ' .. port, vim.log.levels.INFO)
end

-- Stop polling the server
function M.stop_polling()
  if not state.polling then
    return
  end

  if state.timer then
    state.timer:stop()
    state.timer:close()
    state.timer = nil
  end

  state.polling = false
  vim.notify('Stopped polling Continue server', vim.log.levels.INFO)
end

-- Send a message to the Continue server
-- @param port number - Port number
-- @param message string - Message to send
-- @param callback function(err, response) - Optional callback
function M.send_message(port, message, callback)
  local http = require('continue.utils.http')
  local body = vim.json.encode({ message = message })

  http.post(string.format('http://localhost:%d/message', port), body, function(err, response)
    if err then
      vim.notify('Failed to send message: ' .. err, vim.log.levels.ERROR)
      if callback then
        callback(err, nil)
      end
      return
    end

    local ok, data = pcall(vim.json.decode, response.body)
    if ok then
      if callback then
        callback(nil, data)
      end
    else
      if callback then
        callback('Invalid response', nil)
      end
    end
  end)
end

-- Pause/interrupt current agent execution
-- @param port number - Port number
-- @param callback function(err) - Optional callback
function M.pause(port, callback)
  local http = require('continue.utils.http')

  http.post(string.format('http://localhost:%d/pause', port), '{}', function(err, response)
    if err then
      vim.notify('Failed to pause agent: ' .. err, vim.log.levels.ERROR)
      if callback then
        callback(err)
      end
      return
    end

    vim.notify('Agent paused', vim.log.levels.INFO)
    if callback then
      callback(nil)
    end
  end)
end

-- Send permission response for tool execution
-- @param port number - Port number
-- @param request_id string - Permission request ID
-- @param approved boolean - Whether to approve the tool execution
-- @param callback function(err) - Optional callback
function M.send_permission(port, request_id, approved, callback)
  local http = require('continue.utils.http')
  local body = vim.json.encode({
    requestId = request_id,
    approved = approved,
  })

  http.post(string.format('http://localhost:%d/permission', port), body, function(err, _)
    if err then
      vim.notify('Failed to send permission response: ' .. err, vim.log.levels.ERROR)
      if callback then
        callback(err)
      end
      return
    end

    if callback then
      callback(nil)
    end
  end)
end

-- Get git diff from server
-- @param port number - Port number
-- @param callback function(err, diff) - Callback with diff string
function M.get_diff(port, callback)
  local http = require('continue.utils.http')

  http.get(string.format('http://localhost:%d/diff', port), function(err, response)
    if err then
      vim.notify('Failed to get diff: ' .. err, vim.log.levels.ERROR)
      if callback then
        callback(err, nil)
      end
      return
    end

    -- Handle 404 (not a git repo) and 500 (git error)
    if response.status == 404 then
      vim.notify('Not in a git repository', vim.log.levels.WARN)
      if callback then
        callback('Not a git repository', nil)
      end
      return
    end

    if response.status >= 400 then
      vim.notify('Git diff failed: HTTP ' .. response.status, vim.log.levels.ERROR)
      if callback then
        callback('Git error', nil)
      end
      return
    end

    local ok, data = pcall(vim.json.decode, response.body)
    if ok and data.diff then
      if callback then
        callback(nil, data.diff)
      end
    else
      if callback then
        callback('Invalid response', nil)
      end
    end
  end)
end

-- Health check - ping server to verify it's running
-- @param port number - Port number
-- @param callback function(err, ok) - Callback with health status
function M.health_check(port, callback)
  local http = require('continue.utils.http')

  http.get(string.format('http://localhost:%d/state', port), function(err, response)
    if err then
      if callback then
        callback(err, false)
      end
      return
    end

    -- Any successful response means server is healthy
    if response.status >= 200 and response.status < 300 then
      if callback then
        callback(nil, true)
      end
    else
      if callback then
        callback('Unhealthy', false)
      end
    end
  end)
end

-- Get current client status
-- @return table - Status information
function M.status()
  return {
    polling = state.polling,
    port = state.port,
    has_state = state.last_state ~= nil,
    poll_interval = state.poll_interval,
  }
end

-- Calculate optimal polling interval based on server activity
-- @param server_state table - Current server state
-- @return number - Interval in milliseconds
function M.calculate_poll_interval(server_state)
  if not server_state then
    return POLL_INTERVAL_DEFAULT
  end
  
  -- Fast polling when actively processing
  if server_state.isProcessing then
    return POLL_INTERVAL_ACTIVE
  end
  
  -- Fast polling when messages in queue
  if server_state.messageQueueLength and server_state.messageQueueLength > 0 then
    return POLL_INTERVAL_ACTIVE
  end
  
  -- Fast polling when there's a streaming message
  if server_state.chatHistory and #server_state.chatHistory > 0 then
    local last_msg = server_state.chatHistory[#server_state.chatHistory]
    if last_msg.isStreaming then
      return POLL_INTERVAL_ACTIVE
    end
  end
  
  -- Slow polling when idle
  return POLL_INTERVAL_IDLE
end

-- IMPLEMENTATION SUBSTEPS for future enhancements:
-- TODO: Add request queue for rate limiting
-- TODO: Add connection recovery logic

return M