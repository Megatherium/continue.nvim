-- HTTP client using curl (simple and reliable)
-- For production: could use vim.loop TCP for zero dependencies

local M = {}

-- Simple GET request using curl
-- @param url string - Full URL (e.g., "http://localhost:8000/state")
-- @param callback function(err, response) - Called with result
function M.get(url, callback)
  local cmd = string.format('curl -s -w "\\n%%{http_code}" "%s"', url)

  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if not data or #data == 0 then
        vim.schedule(function()
          callback('Empty response', nil)
        end)
        return
      end

      -- Last line is HTTP status code (from -w)
      local status_code = tonumber(data[#data])
      local body_lines = {}
      for i = 1, #data - 1 do
        if data[i] ~= '' then
          table.insert(body_lines, data[i])
        end
      end
      local body = table.concat(body_lines, '\n')

      vim.schedule(function()
        if status_code and status_code >= 200 and status_code < 300 then
          callback(nil, { status = status_code, body = body })
        else
          callback(string.format('HTTP %s', status_code or 'error'), nil)
        end
      end)
    end,
    on_stderr = function(_, data)
      if data and #data > 0 then
        local err_msg = table.concat(data, '\n')
        if err_msg ~= '' then
          vim.schedule(function()
            callback('curl error: ' .. err_msg, nil)
          end)
        end
      end
    end,
    on_exit = function(_, code)
      if code ~= 0 then
        vim.schedule(function()
          callback(string.format('curl exited with code %d', code), nil)
        end)
      end
    end,
  })
end

-- Simple POST request using curl
-- @param url string - Full URL
-- @param body string - JSON string to send
-- @param callback function(err, response)
function M.post(url, body, callback)
  local cmd = string.format(
    'curl -s -w "\\n%%{http_code}" -X POST -H "Content-Type: application/json" -d %s "%s"',
    vim.fn.shellescape(body),
    url
  )

  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if not data or #data == 0 then
        vim.schedule(function()
          callback('Empty response', nil)
        end)
        return
      end

      -- Last line is HTTP status code
      local status_code = tonumber(data[#data])
      local body_lines = {}
      for i = 1, #data - 1 do
        if data[i] ~= '' then
          table.insert(body_lines, data[i])
        end
      end
      local body = table.concat(body_lines, '\n')

      vim.schedule(function()
        if status_code and status_code >= 200 and status_code < 300 then
          callback(nil, { status = status_code, body = body })
        else
          callback(string.format('HTTP %s', status_code or 'error'), nil)
        end
      end)
    end,
    on_stderr = function(_, data)
      if data and #data > 0 then
        local err_msg = table.concat(data, '\n')
        if err_msg ~= '' then
          vim.schedule(function()
            callback('curl error: ' .. err_msg, nil)
          end)
        end
      end
    end,
    on_exit = function(_, code)
      if code ~= 0 then
        vim.schedule(function()
          callback(string.format('curl exited with code %d', code), nil)
        end)
      end
    end,
  })
end

-- TODO: Add request timeout handling
-- TODO: Add retry logic for transient failures
-- TODO: Add request/response logging for debugging
-- TODO: Consider vim.loop TCP implementation for zero curl dependency

return M
