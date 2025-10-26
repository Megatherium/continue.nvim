---@class ContinueJson
---@field encode fun(data: any): string?, string? Encode Lua table to JSON string
---@field decode fun(str: string): any?, string? Decode JSON string to Lua table

-- ============================================================================
-- JSON Utilities
-- ============================================================================
-- Wraps Neovim's built-in vim.json (requires 0.10+)
--
-- IMPLEMENTATION NOTES:
-- - Requires Neovim 0.10+ for vim.json API
-- - Returns (result, error) pattern for all functions
-- - Handles edge cases: nil, empty strings, malformed JSON
-- - No external dependencies (no vendored JSON lib fallback)
--
-- USAGE:
--   local json = require('continue.utils.json')
--   local encoded, err = json.encode({foo = "bar"})
--   if err then
--     print("Encode error:", err)
--   end
--
--   local decoded, err = json.decode('{"foo":"bar"}')
--   if err then
--     print("Decode error:", err)
--   end
-- ============================================================================

local M = {}

-- Check Neovim version requirement (0.10+)
-- vim.json was added in Neovim 0.10.0
local function check_version()
  if not vim.json then
    error(
      "continue.nvim requires Neovim 0.10.0 or later (vim.json not available). "
      .. "Current version: " .. vim.version().major .. "." .. vim.version().minor
    )
  end
end

--- Encode a Lua table to JSON string
---
--- @param data any Lua value to encode (typically a table)
--- @return string? result JSON string if successful
--- @return string? error Error message if encoding failed
---
--- IMPLEMENTATION SUBSTEPS:
--- 1. Validate vim.json is available (version check)
--- 2. Handle nil input (return error)
--- 3. Call vim.json.encode with pcall for error handling
--- 4. Return (result, nil) on success or (nil, error) on failure
function M.encode(data)
  -- Substep 1: Version check
  check_version()

  -- Substep 2: Validate input
  if data == nil then
    return nil, "Cannot encode nil value"
  end

  -- Substep 3: Encode with error handling
  local success, result = pcall(vim.json.encode, data)

  -- Substep 4: Return result or error
  if success then
    return result, nil
  else
    return nil, "JSON encode error: " .. tostring(result)
  end
end

--- Decode a JSON string to Lua table
---
--- @param str string JSON string to decode
--- @return any? result Decoded Lua value if successful
--- @return string? error Error message if decoding failed
---
--- IMPLEMENTATION SUBSTEPS:
--- 1. Validate vim.json is available (version check)
--- 2. Handle empty/nil input (return error)
--- 3. Call vim.json.decode with pcall for error handling
--- 4. Return (result, nil) on success or (nil, error) on failure
function M.decode(str)
  -- Substep 1: Version check
  check_version()

  -- Substep 2: Validate input
  if not str or str == "" then
    return nil, "Cannot decode empty string"
  end

  if type(str) ~= "string" then
    return nil, "Input must be a string, got: " .. type(str)
  end

  -- Substep 3: Decode with error handling
  local success, result = pcall(vim.json.decode, str)

  -- Substep 4: Return result or error
  if success then
    return result, nil
  else
    return nil, "JSON decode error: " .. tostring(result)
  end
end

return M
