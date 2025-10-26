-- Chat UI implementation

local M = {}

local state = {
  bufnr = nil,          -- Chat history buffer
  winnr = nil,          -- Chat history window
  input_bufnr = nil,    -- Input buffer (new)
  input_winnr = nil,    -- Input window (new)
  last_state = nil,
  last_permission = nil,
}

-- Open chat window
function M.open()
  -- Create chat history buffer if it doesn't exist
  if not state.bufnr or not vim.api.nvim_buf_is_valid(state.bufnr) then
    state.bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(state.bufnr, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(state.bufnr, 'filetype', 'markdown')
    vim.api.nvim_buf_set_name(state.bufnr, 'Continue Chat')
  end

  -- Create input buffer if it doesn't exist
  if not state.input_bufnr or not vim.api.nvim_buf_is_valid(state.input_bufnr) then
    state.input_bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(state.input_bufnr, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(state.input_bufnr, 'filetype', 'markdown')
    vim.api.nvim_buf_set_name(state.input_bufnr, 'Continue Input')
    
    -- Make input buffer modifiable
    vim.api.nvim_buf_set_option(state.input_bufnr, 'modifiable', true)
    
    -- Set up input buffer keymaps
    M.setup_input_keymaps(state.input_bufnr)
  end

  -- Calculate window dimensions (80% of screen)
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  
  -- Split: 80% chat history, 20% input
  local chat_height = math.floor(height * 0.8)
  local input_height = height - chat_height - 1  -- -1 for border

  -- Open chat history window (top)
  state.winnr = vim.api.nvim_open_win(state.bufnr, true, {
    relative = 'editor',
    width = width,
    height = chat_height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
  })
  
  -- Set up chat window keymaps
  M.setup_keymaps(state.bufnr)

  -- Open input window (bottom)
  state.input_winnr = vim.api.nvim_open_win(state.input_bufnr, true, {
    relative = 'editor',
    width = width,
    height = input_height,
    row = row + chat_height + 1,  -- +1 for border
    col = col,
    style = 'minimal',
    border = 'rounded',
  })
  
  -- Add input prompt
  vim.api.nvim_buf_set_lines(state.input_bufnr, 0, -1, false, {
    '> Type your message and press <CR> to send...',
  })
  
  -- Move cursor to input window
  vim.api.nvim_set_current_win(state.input_winnr)

  -- Render existing chat history if available
  if state.last_state and state.last_state.chatHistory then
    M.render_full_history(state.last_state.chatHistory)
  else
    -- Show welcome message
    vim.api.nvim_buf_set_option(state.bufnr, 'modifiable', true)
    vim.api.nvim_buf_set_lines(state.bufnr, 0, -1, false, {
      '╔══════════════════════════════════════════════════════════╗',
      '║                  Continue.nvim Chat                      ║',
      '╚══════════════════════════════════════════════════════════╝',
      '',
      'Waiting for messages...',
      '',
      'Type a message below and press <CR> to send',
      'Press q or <Esc> to close',
    })
    vim.api.nvim_buf_set_option(state.bufnr, 'modifiable', false)
  end
end

-- Close chat window
function M.close()
  if state.winnr and vim.api.nvim_win_is_valid(state.winnr) then
    vim.api.nvim_win_close(state.winnr, true)
    state.winnr = nil
  end
  
  if state.input_winnr and vim.api.nvim_win_is_valid(state.input_winnr) then
    vim.api.nvim_win_close(state.input_winnr, true)
    state.input_winnr = nil
  end
end

-- Setup buffer-local keymaps
-- @param bufnr number - Buffer number
function M.setup_keymaps(bufnr)
  -- Close on q
  vim.keymap.set('n', 'q', function()
    M.close()
  end, { buffer = bufnr, desc = 'Close Continue chat' })

  -- Close on <Esc>
  vim.keymap.set('n', '<Esc>', function()
    M.close()
  end, { buffer = bufnr, desc = 'Close Continue chat' })
end

-- Setup input buffer keymaps
-- @param bufnr number - Input buffer number
function M.setup_input_keymaps(bufnr)
  -- Send message on <CR> in insert mode
  vim.keymap.set('i', '<CR>', function()
    M.send_input_message()
  end, { buffer = bufnr, desc = 'Send message' })
  
  -- Send message on <CR> in normal mode
  vim.keymap.set('n', '<CR>', function()
    M.send_input_message()
  end, { buffer = bufnr, desc = 'Send message' })
  
  -- Close on <Esc> in normal mode
  vim.keymap.set('n', '<Esc>', function()
    M.close()
  end, { buffer = bufnr, desc = 'Close Continue chat' })
  
  -- Close on q in normal mode
  vim.keymap.set('n', 'q', function()
    M.close()
  end, { buffer = bufnr, desc = 'Close Continue chat' })
end

-- Send message from input buffer
function M.send_input_message()
  if not state.input_bufnr or not vim.api.nvim_buf_is_valid(state.input_bufnr) then
    return
  end
  
  -- Get all lines from input buffer
  local lines = vim.api.nvim_buf_get_lines(state.input_bufnr, 0, -1, false)
  
  -- Filter out the prompt line and empty lines
  local message_lines = {}
  for _, line in ipairs(lines) do
    if not line:match('^> Type your message') and line ~= '' then
      table.insert(message_lines, line)
    end
  end
  
  local message = table.concat(message_lines, '\n'):gsub('^%s+', ''):gsub('%s+$', '')
  
  if message == '' then
    vim.notify('Please enter a message', vim.log.levels.WARN)
    return
  end
  
  -- Get port from process status
  local process = require('continue.process')
  local status = process.status()
  
  if not status.running then
    vim.notify('Continue server not running. Starting...', vim.log.levels.INFO)
    local continue = require('continue')
    process.start(continue.config)
    
    -- Wait a bit for server to start
    vim.defer_fn(function()
      M.send_message_to_server(message)
    end, 2000)
  else
    M.send_message_to_server(message)
  end
  
  -- Clear input buffer
  vim.api.nvim_buf_set_lines(state.input_bufnr, 0, -1, false, {
    '> Type your message and press <CR> to send...',
  })
end

-- Send message to server via client
function M.send_message_to_server(message)
  local process = require('continue.process')
  local client = require('continue.client')
  local status = process.status()
  
  if not status.running or not status.port then
    vim.notify('Cannot send message: server not running', vim.log.levels.ERROR)
    return
  end
  
  client.send_message(status.port, message, function(err, data)
    if err then
      vim.notify('Failed to send message: ' .. err, vim.log.levels.ERROR)
    else
      -- Message sent successfully - the polling will update the UI
      vim.notify('Message sent (queue position: ' .. (data.position or '?') .. ')', vim.log.levels.INFO)
    end
  end)
end

-- Format a single message for display
-- @param msg table - Message object from server state
-- @return string[] - Lines to render
--
-- IMPLEMENTATION SUBSTEPS:
-- 1. Determine message prefix based on role
-- 2. Handle different message types (tool, system, regular)
-- 3. Format content (preserve line breaks, add indentation)
-- 4. Add streaming indicator if isStreaming
-- 5. Return array of lines
function M.format_message(msg)
  local lines = {}

  -- Substep 1: Role prefix
  local prefix = ''
  if msg.role == 'user' then
    prefix = '🧑 You: '
  elseif msg.role == 'assistant' then
    prefix = '🤖 Assistant: '
  elseif msg.role == 'system' then
    prefix = '⚙️  System: '
  end

  -- Substep 2: Handle special message types
  if msg.messageType == 'tool-start' then
    table.insert(lines, '🔧 Tool: ' .. (msg.toolName or 'unknown'))
    table.insert(lines, '   Starting execution...')
    return lines
  elseif msg.messageType == 'tool-result' then
    table.insert(lines, '🔧 Tool: ' .. (msg.toolName or 'unknown'))
    if msg.toolResult and msg.toolResult ~= '' then
      -- Indent tool result
      for line in msg.toolResult:gmatch('[^\n]+') do
        table.insert(lines, '   ' .. line)
      end
    else
      table.insert(lines, '   (no output)')
    end
    return lines
  elseif msg.messageType == 'tool-error' then
    table.insert(lines, '❌ Tool Error: ' .. (msg.toolName or 'unknown'))
    if msg.content and msg.content ~= '' then
      for line in msg.content:gmatch('[^\n]+') do
        table.insert(lines, '   ' .. line)
      end
    end
    return lines
  end

  -- Substep 3: Format regular content
  if msg.content and msg.content ~= '' then
    -- First line gets prefix
    local content_lines = vim.split(msg.content, '\n', { plain = true })
    if #content_lines > 0 then
      table.insert(lines, prefix .. content_lines[1])
      -- Subsequent lines are indented
      for i = 2, #content_lines do
        table.insert(lines, '   ' .. content_lines[i])
      end
    end
  else
    table.insert(lines, prefix .. '(empty message)')
  end

  -- Substep 4: Streaming indicator
  if msg.isStreaming then
    table.insert(lines, '   ⏳ typing...')
  end

  return lines
end

-- Update UI from new server state
-- @param new_state table - Server state from GET /state
--
-- IMPLEMENTATION SUBSTEPS:
-- 1. Validate buffer exists
-- 2. Compare history length (detect new messages)
-- 3. Detect streaming updates (last message changed)
-- 4. Re-render buffer if changes detected
-- 5. Handle permission prompts
-- 6. Auto-scroll to bottom
function M.update_from_state(new_state)
  -- Substep 1: Validate buffer
  if not state.bufnr or not vim.api.nvim_buf_is_valid(state.bufnr) then
    -- Buffer not open, nothing to update
    return
  end

  local needs_update = false
  local old_history = state.last_state and state.last_state.chatHistory or {}
  local new_history = new_state.chatHistory or {}

  -- Substep 2: Detect new messages
  if #new_history > #old_history then
    needs_update = true
  end

  -- Substep 3: Detect streaming updates (last message content changed)
  if #new_history > 0 and #old_history > 0 then
    local old_last = old_history[#old_history]
    local new_last = new_history[#new_history]

    if old_last.content ~= new_last.content or old_last.isStreaming ~= new_last.isStreaming then
      needs_update = true
    end
  end

  -- Substep 4: Re-render if needed
  if needs_update then
    M.render_full_history(new_history)
  end

  -- Substep 5: Handle permission prompts
  if new_state.pendingPermission and new_state.pendingPermission ~= state.last_permission then
    state.last_permission = new_state.pendingPermission
    M.show_permission_prompt(new_state.pendingPermission)
  end

  state.last_state = new_state
end

-- Render full chat history to buffer
-- @param history table[] - Array of message objects
--
-- IMPLEMENTATION SUBSTEPS:
-- 1. Make buffer modifiable
-- 2. Clear buffer
-- 3. Format each message
-- 4. Add separator between messages
-- 5. Write lines to buffer
-- 6. Make buffer non-modifiable
-- 7. Auto-scroll to bottom
function M.render_full_history(history)
  if not state.bufnr or not vim.api.nvim_buf_is_valid(state.bufnr) then
    return
  end

  -- Substep 1: Make modifiable
  vim.api.nvim_buf_set_option(state.bufnr, 'modifiable', true)

  -- Substep 2: Clear buffer
  vim.api.nvim_buf_set_lines(state.bufnr, 0, -1, false, {})

  -- Substep 3-4: Format messages with separators
  local all_lines = {}
  for i, msg in ipairs(history) do
    local msg_lines = M.format_message(msg)
    for _, line in ipairs(msg_lines) do
      table.insert(all_lines, line)
    end

    -- Add separator between messages (except after last)
    if i < #history then
      table.insert(all_lines, '')
      table.insert(all_lines, string.rep('─', 60))
      table.insert(all_lines, '')
    end
  end

  -- Substep 5: Write to buffer
  vim.api.nvim_buf_set_lines(state.bufnr, 0, -1, false, all_lines)

  -- Substep 6: Make non-modifiable
  vim.api.nvim_buf_set_option(state.bufnr, 'modifiable', false)

  -- Substep 7: Auto-scroll to bottom if window is visible
  if state.winnr and vim.api.nvim_win_is_valid(state.winnr) then
    vim.api.nvim_win_set_cursor(state.winnr, { #all_lines, 0 })
  end
end

-- Handle permission prompts
-- @param permission table - Permission request from server
function M.show_permission_prompt(permission)
  local prompt = string.format('Tool "%s" wants to execute. Approve?', permission.toolName)

  vim.ui.select({ 'Yes', 'No' }, { prompt = prompt }, function(choice)
    if not choice then
      return
    end

    local approved = choice == 'Yes'
    local process = require('continue.process')
    local client = require('continue.client')
    local status = process.status()

    if status.running then
      client.send_permission(status.port, permission.requestId, approved)
      
      -- Clear permission after it's resolved
      state.last_permission = nil
    end
  end)
end

-- IMPLEMENTATION SUBSTEPS for future enhancements:
-- TODO: Add syntax highlighting for code blocks
--   1. Detect code fence markers (```) in message content
--   2. Extract language hint
--   3. Apply treesitter highlighting to code regions
-- TODO: Add input area for typing messages
--   1. Split window horizontally (chat above, input below)
--   2. Make input buffer modifiable
--   3. Map <CR> to send message from input
--   4. Clear input after sending
-- TODO: Add visual feedback for processing state
--   1. Show spinner or progress indicator in status line
--   2. Dim messages while processing
--   3. Highlight active tool execution
-- TODO: Add message actions (copy, retry, edit)
--   1. Add keymaps for message-specific actions
--   2. Extract message under cursor
--   3. Implement copy to clipboard
--   4. Implement retry failed messages

return M