-- Chat UI implementation

local M = {}

local state = {
  bufnr = nil,
  winnr = nil,
  last_state = nil,
}

-- Open chat window
function M.open()
  -- Create buffer if it doesn't exist
  if not state.bufnr or not vim.api.nvim_buf_is_valid(state.bufnr) then
    state.bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(state.bufnr, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(state.bufnr, 'filetype', 'markdown')
    vim.api.nvim_buf_set_name(state.bufnr, 'Continue Chat')

    -- Set up buffer-local keymaps
    M.setup_keymaps(state.bufnr)
  end

  -- Open floating window
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)

  state.winnr = vim.api.nvim_open_win(state.bufnr, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = 'minimal',
    border = 'rounded',
  })

  -- TODO: Render existing chat history if available
  vim.notify('Chat UI opened (TODO: implement message rendering)', vim.log.levels.INFO)
end

-- Close chat window
function M.close()
  if state.winnr and vim.api.nvim_win_is_valid(state.winnr) then
    vim.api.nvim_win_close(state.winnr, true)
    state.winnr = nil
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

  -- TODO: <CR> in insert mode to send message
  -- TODO: Ctrl-C to pause agent
end

-- Render a single message
-- @param msg table - Message object from server state
function M.render_message(msg)
  -- TODO: Implement message rendering
  -- Format message based on role (user/assistant/system)
  -- Handle different message types (tool-start, tool-result, etc.)
  -- Handle streaming updates (isStreaming flag)
end

-- Update UI from new server state
-- @param new_state table - Server state from GET /state
function M.update_from_state(new_state)
  if not state.bufnr or not vim.api.nvim_buf_is_valid(state.bufnr) then
    -- Buffer not open, nothing to update
    return
  end

  -- TODO: Implement state diffing and UI updates
  -- - Compare new_state.chatHistory with state.last_state.chatHistory
  -- - Detect new messages and append them
  -- - Detect streaming updates and update last message
  -- - Handle permission prompts
  -- - Update status line (isProcessing, messageQueueLength)

  state.last_state = new_state
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
    end
  end)
end

-- TODO: Implement message diffing logic
-- TODO: Implement streaming message updates
-- TODO: Implement auto-scroll to bottom
-- TODO: Add syntax highlighting for code blocks
-- TODO: Add input area for typing messages

return M
