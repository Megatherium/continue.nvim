-- HTTP client for Continue server

local M = {}

function M.start_polling(port, callback)
  -- TODO: Implement state polling
  -- See docs/QUICK_REFERENCE.md for implementation
end

function M.send_message(port, message, callback)
  -- TODO: Implement POST /message
end

function M.pause(port, callback)
  -- TODO: Implement POST /pause
end

return M