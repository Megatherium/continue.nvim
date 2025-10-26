-- HTTP client using curl (simple and reliable)
-- For production: could use vim.loop TCP for zero dependencies
--
-- IMPLEMENTATION NOTES:
-- - Uses vim.fn.jobstart for async requests
-- - Default timeout: 5 seconds via curl --max-time
-- - Supports job abortion via returned job_id
-- - Callbacks always called via vim.schedule for safety

local M = {}

-- Default timeout in seconds
local DEFAULT_TIMEOUT = 5

-- Simple GET request using curl
-- @param url string - Full URL (e.g., "http://localhost:8000/state")
-- @param callback function(err, response) - Called with result
-- @param opts table|nil - Optional {timeout: number (seconds)}
-- @return number - Job ID (can be used with vim.fn.jobstop to cancel)
function M.get(url, callback, opts)
  opts = opts or {}
  local timeout = opts.timeout or DEFAULT_TIMEOUT
  local cmd = string.format(
    'curl -s -w "\\n%%{http_code}" --max-time %d --connect-timeout %d "%s"',
    timeout,
    timeout,
    url
  )

  return vim.fn.jobstart(cmd, {
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
-- @param opts table|nil - Optional {timeout: number (seconds)}
-- @return number - Job ID (can be used with vim.fn.jobstop to cancel)
function M.post(url, body, callback, opts)
  opts = opts or {}
  local timeout = opts.timeout or DEFAULT_TIMEOUT
  local cmd = string.format(
    'curl -s -w "\\n%%{http_code}" --max-time %d --connect-timeout %d -X POST -H "Content-Type: application/json" -d %s "%s"',
    timeout,
    timeout,
    vim.fn.shellescape(body),
    url
  )

  return vim.fn.jobstart(cmd, {
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

-- Check if curl is available
-- @return boolean - True if curl is installed
function M.has_curl()
  return vim.fn.executable('curl') == 1
end

-- IMPLEMENTATION SUBSTEPS for future enhancements:
-- TODO: Add retry logic for transient failures
--   1. Detect transient errors (connection refused, timeout)
--   2. Implement exponential backoff
--   3. Max retry count from opts
-- TODO: Add request/response logging for debugging
--   1. Log to :messages with vim.log.levels.DEBUG
--   2. Optional log file path in opts
-- TODO: Consider vim.loop TCP implementation for zero curl dependency
--   1. Implement HTTP/1.1 request builder
--   2. Handle chunked transfer encoding
--   3. Parse HTTP headers properly

return M
