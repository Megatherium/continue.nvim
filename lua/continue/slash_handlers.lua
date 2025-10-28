-- Continue.nvim: Local slash command handlers
-- Handles commands that can be executed client-side

local M = {}

---Handle /clear command - clear chat history
---@param chat_ui table Chat UI module
---@return boolean True if handled locally
function M.handle_clear(chat_ui)
  -- Confirm with user
  vim.ui.select({ 'Yes', 'No' }, {
    prompt = 'Clear all chat history?',
  }, function(choice)
    if choice == 'Yes' then
      chat_ui.clear_history()
      vim.notify('Chat history cleared', vim.log.levels.INFO)
    end
  end)

  return true -- Handled locally
end

---Handle /help command - show help overlay
---@return boolean True if handled locally
function M.handle_help()
  local help_overlay = require('continue.ui.help_overlay')
  help_overlay.show()
  return true
end

---Handle /exit command - close chat window
---@param chat_ui table Chat UI module
---@return boolean True if handled locally
function M.handle_exit(chat_ui)
  chat_ui.close()
  return true
end

---Check if a command can be handled locally
---@param command string Command name (without /)
---@return boolean True if can be handled locally
function M.can_handle_locally(command)
  local local_commands = {
    'clear',
    'help',
    'exit',
  }

  return vim.tbl_contains(local_commands, command)
end

---Handle a slash command
---@param input string Full input with slash command
---@param chat_ui table Chat UI module
---@return boolean True if handled locally, false if should be sent to server
function M.handle(input, chat_ui)
  -- Extract command
  local command = input:match('^/(%S+)')
  if not command then
    return false
  end

  -- Try local handlers
  if command == 'clear' then
    return M.handle_clear(chat_ui)
  elseif command == 'help' then
    return M.handle_help()
  elseif command == 'exit' then
    return M.handle_exit(chat_ui)
  end

  -- Not handled locally, send to server
  return false
end

return M
