-- Continue.nvim: Slash commands cache and fuzzy finder
-- Caches available slash commands and provides fuzzy matching

local M = {}

-- System slash commands from Continue CLI
-- Source: source/extensions/cli/src/commands/commands.ts
local SYSTEM_COMMANDS = {
  { name = 'help', description = 'Show help message', category = 'system' },
  { name = 'clear', description = 'Clear the chat history', category = 'system' },
  { name = 'exit', description = 'Exit the chat', category = 'system' },
  { name = 'config', description = 'Switch configuration or organization', category = 'system' },
  { name = 'login', description = 'Authenticate with your account', category = 'system' },
  { name = 'logout', description = 'Sign out of your current session', category = 'system' },
  { name = 'whoami', description = 'Check who you\'re currently logged in as', category = 'system' },
  { name = 'info', description = 'Show session information', category = 'system' },
  { name = 'model', description = 'Switch between available chat models', category = 'system' },
  { name = 'compact', description = 'Summarize chat history into a compact form', category = 'system' },
  { name = 'mcp', description = 'Manage MCP server connections', category = 'system' },
  { name = 'resume', description = 'Resume a previous chat session', category = 'system' },
  { name = 'fork', description = 'Start a forked chat session from the current history', category = 'system' },
  { name = 'title', description = 'Set the title for the current session', category = 'system' },
  { name = 'init', description = 'Create an AGENTS.md file', category = 'system' },
  { name = 'update', description = 'Update the Continue CLI', category = 'system' },
}

-- Cache for all commands (system + assistant custom commands)
local cached_commands = nil
local cache_timestamp = 0
local CACHE_TTL = 60000 -- 60 seconds

---Initialize the commands cache
---@param port number Server port (unused for now, reserved for future GET /commands endpoint)
---@param callback function(err: string?, commands: table?) Callback with cached commands
function M.init(port, callback)
  -- For now, we just use system commands
  -- TODO: Future enhancement - fetch custom commands from server via GET /commands endpoint
  -- The 'port' parameter will be used when we implement server-side command fetching
  _ = port -- Suppress unused variable warning

  cached_commands = vim.tbl_deep_extend('force', {}, SYSTEM_COMMANDS)
  cache_timestamp = vim.loop.now()

  if callback then
    callback(nil, cached_commands)
  end
end

---Get all cached commands
---@return table List of commands with name, description, category
function M.get_all()
  -- Lazy init if not cached
  if not cached_commands or (vim.loop.now() - cache_timestamp) > CACHE_TTL then
    cached_commands = vim.tbl_deep_extend('force', {}, SYSTEM_COMMANDS)
    cache_timestamp = vim.loop.now()
  end

  return cached_commands
end

---Fuzzy match a filter string against commands
---Prioritizes: exact match > starts with > contains
---@param filter string The search filter (without leading /)
---@return table Sorted list of matching commands
function M.fuzzy_find(filter)
  local all_commands = M.get_all()

  if not filter or filter == '' then
    return all_commands
  end

  local filter_lower = filter:lower()
  local matches = {}

  for _, cmd in ipairs(all_commands) do
    local name_lower = cmd.name:lower()
    local score = 0

    -- Exact match (highest priority)
    if name_lower == filter_lower then
      score = 1000
    -- Starts with (high priority)
    elseif vim.startswith(name_lower, filter_lower) then
      score = 500
    -- Contains (medium priority)
    elseif name_lower:find(filter_lower, 1, true) then
      score = 100
    end

    if score > 0 then
      table.insert(matches, {
        command = cmd,
        score = score,
      })
    end
  end

  -- Sort by score (descending)
  table.sort(matches, function(a, b)
    if a.score == b.score then
      return a.command.name < b.command.name
    end
    return a.score > b.score
  end)

  -- Extract commands from matches
  local result = {}
  for _, match in ipairs(matches) do
    table.insert(result, match.command)
  end

  return result
end

---Get a specific command by name
---@param name string Command name
---@return table? Command object or nil if not found
function M.get_command(name)
  local all_commands = M.get_all()

  for _, cmd in ipairs(all_commands) do
    if cmd.name == name then
      return cmd
    end
  end

  return nil
end

---Check if a string is a valid slash command
---@param input string Input string
---@return boolean, string? is_command, command_name
function M.is_slash_command(input)
  if not vim.startswith(input, '/') then
    return false, nil
  end

  local command_name = input:match('^/(%S+)')
  if not command_name then
    return false, nil
  end

  local cmd = M.get_command(command_name)
  return cmd ~= nil, command_name
end

---Format a command for display
---@param cmd table Command object
---@param max_name_len number? Maximum name length for padding
---@return string Formatted command string
function M.format_command(cmd, max_name_len)
  max_name_len = max_name_len or 12
  local name_padded = string.format('%-' .. max_name_len .. 's', '/' .. cmd.name)
  local category_icon = cmd.category == 'system' and '⚙' or '🤖'

  return string.format('%s %s   %s', category_icon, name_padded, cmd.description)
end

---Clear the cache (force refresh on next access)
function M.clear_cache()
  cached_commands = nil
  cache_timestamp = 0
end

return M
