# API Integration Guide: HTTP Protocol → Neovim

This document shows how to integrate the Continue CLI's HTTP API with Neovim.

## Overview

**Architecture**: HTTP polling client talking to `cn serve` backend

**Key Responsibilities**:
- **cn serve**: All AI logic, agent execution, tool calls
- **Neovim plugin**: Process management, HTTP client, UI rendering

**Protocol**: REST API on `localhost:8000` (default)

---

## HTTP Endpoints → Neovim Implementation

### GET /state (Polling)

**Purpose**: Get current agent state
**Frequency**: Every 500ms
**Returns**: Chat history, processing status, permissions

**Response**:
```json
{
  "chatHistory": [
    {
      "role": "user" | "assistant" | "system",
      "content": "string",
      "isStreaming": boolean,
      "messageType": "tool-start" | "tool-result" | "tool-error" | "system",
      "toolName": "string",
      "toolResult": "string"
    }
  ],
  "isProcessing": boolean,
  "messageQueueLength": number,
  "pendingPermission": {
    "requestId": "string",
    "toolName": "string",
    "args": {}
  } | null
}
```

**Neovim Implementation**:
```lua
-- lua/continue/client.lua
local M = {}
local state = {}

-- Start polling timer
function M.start_polling(port, callback)
  local timer = vim.loop.new_timer()

  timer:start(0, 500, vim.schedule_wrap(function()
    local url = string.format('http://localhost:%d/state', port)

    M.http_get(url, function(response)
      if response then
        local ok, parsed = pcall(vim.json.decode, response.body)
        if ok then
          callback(parsed)
        else
          vim.notify('Failed to parse /state response', vim.log.levels.ERROR)
        end
      end
    end)
  end))

  return timer
end

-- Stop polling
function M.stop_polling(timer)
  if timer then
    timer:stop()
    timer:close()
  end
end
```

**UI Update Pattern**:
```lua
-- lua/continue/ui/chat.lua
local M = {}
local last_state = nil

function M.update_from_state(new_state)
  -- Diff chatHistory to find new messages
  if last_state then
    local old_count = #last_state.chatHistory
    local new_count = #new_state.chatHistory

    if new_count > old_count then
      -- Append new messages
      for i = old_count + 1, new_count do
        M.append_message(new_state.chatHistory[i])
      end
    elseif new_count < old_count then
      -- Full refresh (message removed/interrupted)
      M.render_all(new_state.chatHistory)
    else
      -- Check last message for streaming updates
      local last_msg = new_state.chatHistory[new_count]
      if last_msg and last_msg.isStreaming then
        M.update_streaming_message(last_msg)
      end
    end
  else
    -- First render
    M.render_all(new_state.chatHistory)
  end

  -- Update status line
  M.update_status(new_state.isProcessing, new_state.messageQueueLength)

  -- Handle permission requests
  if new_state.pendingPermission then
    M.show_permission_prompt(new_state.pendingPermission)
  end

  last_state = new_state
end
```

---

### POST /message (Send User Input)

**Purpose**: Send message to agent
**Triggers**: User types in chat buffer, command invocation
**Returns**: Queue position

**Request**:
```json
{
  "message": "string"
}
```

**Response**:
```json
{
  "queued": true,
  "position": number
}
```

**Neovim Implementation**:
```lua
-- lua/continue/client.lua
function M.send_message(port, message, callback)
  local url = string.format('http://localhost:%d/message', port)
  local body = vim.json.encode({ message = message })

  M.http_post(url, body, function(response)
    if response and response.status == 200 then
      local ok, data = pcall(vim.json.decode, response.body)
      if ok then
        callback(nil, data)
      else
        callback('Invalid response')
      end
    else
      callback(response and response.status or 'Request failed')
    end
  end)
end
```

**Command Integration**:
```lua
-- lua/continue/commands.lua
vim.api.nvim_create_user_command('Continue', function(opts)
  local message = opts.args

  if message == '' then
    -- Open chat UI
    require('continue.ui.chat').open()
  else
    -- Send message directly
    require('continue.client').send_message(8000, message, function(err, response)
      if err then
        vim.notify('Failed to send message: ' .. err, vim.log.levels.ERROR)
      else
        vim.notify('Message queued at position ' .. response.position, vim.log.levels.INFO)
      end
    end)
  end
end, {
  nargs = '*',
  desc = 'Continue AI assistant',
})
```

**Chat Buffer Integration**:
```lua
-- lua/continue/ui/chat.lua
function M.setup_keymaps(bufnr)
  -- Submit message on <CR> in insert mode
  vim.keymap.set('i', '<CR>', function()
    local line = vim.api.nvim_get_current_line()
    if line ~= '' then
      require('continue.client').send_message(8000, line, function(err)
        if not err then
          -- Clear input line
          vim.api.nvim_set_current_line('')
        end
      end)
    end
  end, { buffer = bufnr })

  -- Interrupt on <Esc>
  vim.keymap.set('n', '<Esc>', function()
    require('continue.client').pause(8000)
  end, { buffer = bufnr })
end
```

---

### POST /permission (Tool Approval)

**Purpose**: Approve/reject tool execution
**Triggers**: User responds to permission prompt

**Request**:
```json
{
  "requestId": "string",
  "approved": boolean
}
```

**Neovim Implementation**:
```lua
-- lua/continue/client.lua
function M.send_permission(port, request_id, approved, callback)
  local url = string.format('http://localhost:%d/permission', port)
  local body = vim.json.encode({
    requestId = request_id,
    approved = approved
  })

  M.http_post(url, body, callback)
end
```

**Permission Prompt**:
```lua
-- lua/continue/ui/chat.lua
function M.show_permission_prompt(permission)
  local prompt = string.format(
    'Tool "%s" wants to execute.\nArgs: %s\nApprove?',
    permission.toolName,
    vim.inspect(permission.args)
  )

  vim.ui.select({'Yes', 'No'}, {
    prompt = prompt,
  }, function(choice)
    local approved = choice == 'Yes'
    require('continue.client').send_permission(
      8000,
      permission.requestId,
      approved,
      function(err)
        if err then
          vim.notify('Failed to send permission response', vim.log.levels.ERROR)
        end
      end
    )
  end)
end
```

---

### POST /pause (Interrupt Execution)

**Purpose**: Stop current agent execution
**Triggers**: User presses Escape or `:ContinuePause`

**Neovim Implementation**:
```lua
-- lua/continue/client.lua
function M.pause(port, callback)
  local url = string.format('http://localhost:%d/pause', port)
  M.http_post(url, '{}', function(response)
    if response and response.status == 200 then
      vim.notify('Agent paused', vim.log.levels.INFO)
      if callback then callback(nil) end
    else
      if callback then callback('Failed to pause') end
    end
  end)
end
```

**Command**:
```lua
vim.api.nvim_create_user_command('ContinuePause', function()
  require('continue.client').pause(8000)
end, { desc = 'Pause Continue agent execution' })
```

---

### GET /diff (Git Integration)

**Purpose**: Get git diff from working tree
**Use case**: Show changes made by agent

**Response**:
```json
{
  "diff": "string"
}
```

**Neovim Implementation**:
```lua
-- lua/continue/commands.lua
vim.api.nvim_create_user_command('ContinueDiff', function()
  require('continue.client').get_diff(8000, function(err, diff)
    if err then
      vim.notify('Failed to get diff: ' .. err, vim.log.levels.ERROR)
      return
    end

    -- Show in split
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(diff, '\n'))
    vim.api.nvim_buf_set_option(bufnr, 'filetype', 'diff')

    vim.cmd('split')
    vim.api.nvim_win_set_buf(0, bufnr)
  end)
end, { desc = 'Show git diff from Continue agent' })
```

---

### POST /exit (Graceful Shutdown)

**Purpose**: Stop cn serve
**Triggers**: `:ContinueStop`, `VimLeavePre`

**Neovim Implementation**:
```lua
-- lua/continue/process.lua
function M.stop()
  if not state.running then return end

  -- Try graceful shutdown
  require('continue.client').exit(state.port, function(err)
    if err then
      vim.notify('Graceful shutdown failed, forcing...', vim.log.levels.WARN)
      -- Force kill after 2 seconds
      vim.defer_fn(function()
        if state.job_id then
          vim.fn.jobstop(state.job_id)
        end
      end, 2000)
    end
  end)
end

-- Auto-cleanup
vim.api.nvim_create_autocmd('VimLeavePre', {
  callback = function()
    M.stop()
  end,
})
```

---

## HTTP Client Implementation

### Option 1: Using vim.loop (libuv)

**Pros**: No external dependencies, async
**Cons**: More code, manual HTTP parsing

```lua
-- lua/continue/utils/http.lua
local M = {}

function M.get(url, callback)
  local parsed = M.parse_url(url)
  local client = vim.loop.new_tcp()

  client:connect(parsed.host, parsed.port, function(err)
    if err then
      callback(nil, err)
      return
    end

    local request = string.format(
      "GET %s HTTP/1.1\r\nHost: %s\r\nConnection: close\r\n\r\n",
      parsed.path,
      parsed.host
    )

    client:write(request)

    local response = ''
    client:read_start(function(err, chunk)
      if err then
        callback(nil, err)
        return
      end

      if chunk then
        response = response .. chunk
      else
        -- Parse HTTP response
        local body = response:match('\r\n\r\n(.*)$')
        vim.schedule(function()
          callback({ body = body, status = 200 })
        end)
        client:close()
      end
    end)
  end)
end

function M.post(url, body, callback)
  local parsed = M.parse_url(url)
  local client = vim.loop.new_tcp()

  client:connect(parsed.host, parsed.port, function(err)
    if err then
      callback(nil, err)
      return
    end

    local request = string.format(
      "POST %s HTTP/1.1\r\nHost: %s\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s",
      parsed.path,
      parsed.host,
      #body,
      body
    )

    client:write(request)

    local response = ''
    client:read_start(function(err, chunk)
      if err then
        callback(nil, err)
        return
      end

      if chunk then
        response = response .. chunk
      else
        local body = response:match('\r\n\r\n(.*)$')
        vim.schedule(function()
          callback({ body = body, status = 200 })
        end)
        client:close()
      end
    end)
  end)
end

function M.parse_url(url)
  local host, port, path = url:match('http://([^:]+):(%d+)(.*)')
  if not host then
    host, path = url:match('http://([^/]+)(.*)')
    port = 80
  end
  return { host = host, port = tonumber(port), path = path == '' and '/' or path }
end

return M
```

### Option 2: Using curl (simpler)

**Pros**: Simple, robust
**Cons**: Blocks, requires curl installed

```lua
-- lua/continue/utils/http.lua
local M = {}

function M.get(url, callback)
  local cmd = string.format('curl -s "%s"', url)

  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data then
        local body = table.concat(data, '\n')
        vim.schedule(function()
          callback({ body = body, status = 200 })
        end)
      end
    end,
    on_exit = function(_, code)
      if code ~= 0 then
        vim.schedule(function()
          callback(nil, 'curl failed with code ' .. code)
        end)
      end
    end,
  })
end

function M.post(url, body, callback)
  local cmd = string.format('curl -s -X POST -H "Content-Type: application/json" -d %s "%s"',
    vim.fn.shellescape(body),
    url
  )

  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data then
        local body = table.concat(data, '\n')
        vim.schedule(function()
          callback({ body = body, status = 200 })
        end)
      end
    end,
    on_exit = function(_, code)
      if code ~= 0 then
        vim.schedule(function()
          callback(nil, 'curl failed with code ' .. code)
        end)
      end
    end,
  })
end

return M
```

---

## JSON Handling

Neovim 0.10+ has built-in JSON support via `vim.json`:

```lua
-- Encode
local json_string = vim.json.encode({ message = 'Hello' })

-- Decode (with error handling)
local ok, data = pcall(vim.json.decode, json_string)
if ok then
  print('Decoded:', data.message)
else
  vim.notify('Invalid JSON', vim.log.levels.ERROR)
end
```

---

## Process Management Patterns

### Spawning cn serve

```lua
-- lua/continue/process.lua
local M = {}
local state = {
  job_id = nil,
  port = 8000,
  running = false,
}

function M.start(opts)
  opts = opts or {}
  local port = opts.port or 8000
  local timeout = opts.timeout or 300

  local cmd = {
    'cn',
    'serve',
    '--port', tostring(port),
    '--timeout', tostring(timeout),
  }

  if opts.config then
    vim.list_extend(cmd, { '--config', opts.config })
  end

  state.job_id = vim.fn.jobstart(cmd, {
    on_stdout = function(_, data)
      for _, line in ipairs(data) do
        if line ~= '' then
          vim.notify('[cn serve] ' .. line, vim.log.levels.INFO)
        end
      end
    end,
    on_stderr = function(_, data)
      for _, line in ipairs(data) do
        if line ~= '' then
          vim.notify('[cn serve ERROR] ' .. line, vim.log.levels.ERROR)
        end
      end
    end,
    on_exit = function(_, code)
      state.running = false
      state.job_id = nil
      if code ~= 0 then
        vim.notify('cn serve exited with code ' .. code, vim.log.levels.ERROR)
      end
    end,
  })

  if state.job_id <= 0 then
    vim.notify('Failed to start cn serve', vim.log.levels.ERROR)
    return false
  end

  state.port = port
  state.running = true

  return true
end

return M
```

### Health Checking

```lua
function M.wait_for_ready(timeout_ms, callback)
  local start = vim.loop.now()
  local timer = vim.loop.new_timer()

  timer:start(100, 100, vim.schedule_wrap(function()
    require('continue.client').health_check(state.port, function(ok)
      if ok then
        timer:stop()
        timer:close()
        callback(nil)
      elseif vim.loop.now() - start > timeout_ms then
        timer:stop()
        timer:close()
        M.stop()
        callback('Timeout waiting for cn serve to start')
      end
    end)
  end))
end
```

---

## Testing Strategy

### Mock HTTP Server

```lua
-- tests/mock_server.lua
local M = {}

function M.start()
  -- Simple mock for testing
  local state = {
    chatHistory = {},
    isProcessing = false,
    messageQueueLength = 0,
  }

  return {
    get_state = function() return state end,
    send_message = function(msg)
      table.insert(state.chatHistory, { role = 'user', content = msg })
      state.messageQueueLength = 1
      return { queued = true, position = 1 }
    end,
  }
end

return M
```

### Integration Tests

```lua
-- tests/client_spec.lua
describe('HTTP client', function()
  it('can poll state', function()
    local client = require('continue.client')
    local got_response = false

    client.get_state(8000, function(err, state)
      assert.is_nil(err)
      assert.is_not_nil(state.chatHistory)
      got_response = true
    end)

    vim.wait(5000, function() return got_response end)
    assert.is_true(got_response)
  end)
end)
```

---

*Last updated: 2025-10-26*
*Architecture: HTTP client for cn serve*