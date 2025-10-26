-- HTTP client for Continue server state management

local M = {}

local state = {
  timer = nil,
  polling = false,
  last_state = nil,
  port = nil,
}

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

      state.last_state = server_state
    end)
  end

  -- Start polling at 500ms intervals
  -- TODO: Implement dynamic polling interval based on activity
  state.timer:start(0, 500, vim.schedule_wrap(poll))

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

-- Get current client status
-- @return table - Status information
function M.status()
  return {
    polling = state.polling,
    port = state.port,
    has_state = state.last_state ~= nil,
  }
end

-- TODO: Implement GET /diff endpoint
-- TODO: Add dynamic polling interval (100ms when active, 1000ms when idle)
-- TODO: Add request queue for rate limiting
-- TODO: Add connection recovery logic

return M
