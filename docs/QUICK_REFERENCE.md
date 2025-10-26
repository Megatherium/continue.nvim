# Quick Reference: Continue.nvim HTTP Client

One-page cheatsheet for building the Continue.nvim HTTP client. Keep this open while coding.

## Architecture Overview

```
┌─────────────────┐
│  Neovim Plugin  │
│  • Process mgmt │──spawn──┐
│  • HTTP client  │──poll───┼─▶ cn serve (port 8000)
│  • UI rendering │         │   • AI agent
└─────────────────┘         │   • LLM APIs
                            │   • Tools/MCP
                            └───────────────
```

**Key Principle**: Neovim is just a thin UI client. ALL AI logic lives in `cn serve`.

---

## Quick Start Template

```lua
-- lua/continue/init.lua
local M = {}

M.config = {
  port = 8000,
  timeout = 300,  -- seconds
  auto_start = true,
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})

  -- Start cn serve if auto_start
  if M.config.auto_start then
    require('continue.process').start(M.config)
    require('continue.client').start_polling(M.config.port)
  end

  -- Register commands
  require('continue.commands').setup()
end

return M
```

---

## HTTP Client Snippets

### GET Request (curl-based)

```lua
local function http_get(url, callback)
  vim.fn.jobstart(string.format('curl -s "%s"', url), {
    stdout_buffered = true,
    on_stdout = function(_, data)
      local body = table.concat(data, '\n')
      vim.schedule(function()
        callback(nil, body)
      end)
    end,
    on_exit = function(_, code)
      if code ~= 0 then
        vim.schedule(function()
          callback('Request failed')
        end)
      end
    end,
  })
end
```

### POST Request (curl-based)

```lua
local function http_post(url, body, callback)
  local cmd = string.format(
    'curl -s -X POST -H "Content-Type: application/json" -d %s "%s"',
    vim.fn.shellescape(body),
    url
  )

  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      local response = table.concat(data, '\n')
      vim.schedule(function()
        callback(nil, response)
      end)
    end,
    on_exit = function(_, code)
      if code ~= 0 then
        vim.schedule(function()
          callback('Request failed')
        end)
      end
    end,
  })
end
```

### State Polling (500ms interval)

```lua
local function start_polling(port, on_state)
  local timer = vim.loop.new_timer()

  timer:start(0, 500, vim.schedule_wrap(function()
    http_get(
      string.format('http://localhost:%d/state', port),
      function(err, body)
        if not err then
          local ok, state = pcall(vim.json.decode, body)
          if ok then
            on_state(state)
          end
        end
      end
    )
  end))

  return timer
end

-- Stop polling
local function stop_polling(timer)
  if timer then
    timer:stop()
    timer:close()
  end
end
```

---

## Process Management Snippets

### Spawn cn serve

```lua
local function start_cn_serve(port)
  local job_id = vim.fn.jobstart(
    { 'cn', 'serve', '--port', tostring(port) },
    {
      on_stdout = function(_, data)
        -- Log output
        for _, line in ipairs(data) do
          if line ~= '' then
            print('[cn serve] ' .. line)
          end
        end
      end,
      on_exit = function(_, code)
        if code ~= 0 then
          vim.notify('cn serve exited with code ' .. code, vim.log.levels.ERROR)
        end
      end,
    }
  )

  return job_id > 0 and job_id or nil
end
```

### Health Check

```lua
local function wait_for_ready(port, timeout_ms, callback)
  local start = vim.loop.now()
  local timer = vim.loop.new_timer()

  timer:start(100, 100, vim.schedule_wrap(function()
    http_get(
      string.format('http://localhost:%d/state', port),
      function(err, _)
        if not err then
          -- Server is ready
          timer:stop()
          timer:close()
          callback(nil)
        elseif vim.loop.now() - start > timeout_ms then
          -- Timeout
          timer:stop()
          timer:close()
          callback('Timeout')
        end
      end
    )
  end))
end
```

### Graceful Shutdown

```lua
local function stop_cn_serve(port, job_id)
  -- Try graceful shutdown first
  http_post(
    string.format('http://localhost:%d/exit', port),
    '{}',
    function(err)
      if err then
        -- Force kill after 2 seconds
        vim.defer_fn(function()
          if job_id then
            vim.fn.jobstop(job_id)
          end
        end, 2000)
      end
    end
  )
end
```

---

## Message Handling Snippets

### Send User Message

```lua
local function send_message(port, message)
  local body = vim.json.encode({ message = message })

  http_post(
    string.format('http://localhost:%d/message', port),
    body,
    function(err, response)
      if err then
        vim.notify('Failed to send message: ' .. err, vim.log.levels.ERROR)
      else
        local ok, data = pcall(vim.json.decode, response)
        if ok then
          vim.notify('Message queued at position ' .. data.position, vim.log.levels.INFO)
        end
      end
    end
  )
end
```

### Handle Permission Requests

```lua
local function handle_permission(state)
  if not state.pendingPermission then return end

  local perm = state.pendingPermission
  local prompt = string.format(
    'Tool "%s" wants to execute. Approve?',
    perm.toolName
  )

  vim.ui.select({'Yes', 'No'}, { prompt = prompt }, function(choice)
    local approved = choice == 'Yes'
    local body = vim.json.encode({
      requestId = perm.requestId,
      approved = approved
    })

    http_post(
      string.format('http://localhost:%d/permission', port),
      body,
      function(err)
        if err then
          vim.notify('Failed to send permission', vim.log.levels.ERROR)
        end
      end
    )
  end)
end
```

### Pause Execution

```lua
local function pause_agent(port)
  http_post(
    string.format('http://localhost:%d/pause', port),
    '{}',
    function(err)
      if not err then
        vim.notify('Agent paused', vim.log.levels.INFO)
      end
    end
  )
end
```

---

## UI Rendering Snippets

### Create Chat Buffer

```lua
local function create_chat_buffer()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(bufnr, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(bufnr, 'filetype', 'markdown')
  vim.api.nvim_buf_set_name(bufnr, 'Continue Chat')

  return bufnr
end
```

### Render Message

```lua
local function render_message(bufnr, msg)
  local lines = {}

  -- Header
  if msg.role == 'user' then
    table.insert(lines, '# You')
  elseif msg.role == 'assistant' then
    table.insert(lines, '# Assistant')
  end

  table.insert(lines, '')

  -- Content
  for line in msg.content:gmatch('[^\n]+') do
    table.insert(lines, line)
  end

  table.insert(lines, '')
  table.insert(lines, '---')
  table.insert(lines, '')

  -- Append to buffer
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, line_count, -1, false, lines)
end
```

### Update Streaming Message

```lua
local function update_streaming_message(bufnr, msg)
  -- Find last message block and update it
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Simple approach: replace last content block
  -- (In production, track message indices)
  local last_content_start = #lines - 10  -- estimate

  local new_lines = {}
  for line in msg.content:gmatch('[^\n]+') do
    table.insert(new_lines, line)
  end

  vim.api.nvim_buf_set_lines(
    bufnr,
    last_content_start,
    -1,
    false,
    new_lines
  )
end
```

### Floating Window

```lua
local function open_chat_window(bufnr)
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)

  local win_id = vim.api.nvim_open_win(bufnr, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = 'minimal',
    border = 'rounded',
  })

  return win_id
end
```

---

## Command Registration

```lua
-- lua/continue/commands.lua
local M = {}

function M.setup()
  -- :Continue [message] - Open chat or send message
  vim.api.nvim_create_user_command('Continue', function(opts)
    if opts.args == '' then
      require('continue.ui.chat').open()
    else
      require('continue.client').send_message(8000, opts.args)
    end
  end, {
    nargs = '*',
    desc = 'Continue AI assistant',
  })

  -- :ContinueStart - Start cn serve
  vim.api.nvim_create_user_command('ContinueStart', function()
    require('continue.process').start()
  end, { desc = 'Start Continue server' })

  -- :ContinueStop - Stop cn serve
  vim.api.nvim_create_user_command('ContinueStop', function()
    require('continue.process').stop()
  end, { desc = 'Stop Continue server' })

  -- :ContinuePause - Pause agent
  vim.api.nvim_create_user_command('ContinuePause', function()
    require('continue.client').pause(8000)
  end, { desc = 'Pause Continue agent' })

  -- :ContinueDiff - Show git diff
  vim.api.nvim_create_user_command('ContinueDiff', function()
    require('continue.commands').show_diff()
  end, { desc = 'Show git diff from Continue' })
end

return M
```

---

## JSON Handling

Neovim 0.10+ has built-in JSON support:

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

## State Management Pattern

```lua
-- lua/continue/state.lua
local M = {}

local state = {
  process = {
    job_id = nil,
    port = 8000,
    running = false,
  },
  client = {
    timer = nil,
    polling = false,
  },
  ui = {
    bufnr = nil,
    winnr = nil,
  },
  chat = {
    history = {},
    is_processing = false,
  },
}

function M.get() return state end
function M.update(key, value) state[key] = value end

return M
```

---

## Debugging Snippets

### Log to File

```lua
local function log(msg)
  local log_file = io.open('/tmp/continue-nvim.log', 'a')
  if log_file then
    log_file:write(os.date('[%Y-%m-%d %H:%M:%S] ') .. msg .. '\n')
    log_file:close()
  end
end
```

### Inspect State

```lua
:lua print(vim.inspect(require('continue.state').get()))
```

### Check Health

```lua
-- In plugin/continue.lua
vim.api.nvim_create_user_command('ContinueHealth', function()
  local state = require('continue.state').get()

  local health = {
    process_running = state.process.running,
    polling_active = state.client.polling,
    chat_buffer = state.ui.bufnr,
  }

  print(vim.inspect(health))
end, {})
```

---

## Auto-Cleanup Pattern

```lua
-- lua/continue/init.lua
local augroup = vim.api.nvim_create_augroup('Continue', { clear = true })

-- Stop cn serve on exit
vim.api.nvim_create_autocmd('VimLeavePre', {
  group = augroup,
  callback = function()
    require('continue.process').stop()
  end,
})

-- Clean up buffers
vim.api.nvim_create_autocmd('BufDelete', {
  group = augroup,
  pattern = 'Continue Chat',
  callback = function()
    -- Cleanup UI state
    require('continue.state').update('ui', { bufnr = nil, winnr = nil })
  end,
})
```

---

## Common Patterns

### Safe HTTP Call

```lua
local function safe_http_post(url, body, callback)
  local ok, err = pcall(function()
    http_post(url, body, callback)
  end)

  if not ok then
    vim.schedule(function()
      vim.notify('HTTP error: ' .. err, vim.log.levels.ERROR)
    end)
  end
end
```

### Debounced Polling

```lua
local last_poll = 0
local function poll_if_needed()
  local now = vim.loop.now()
  if now - last_poll > 500 then  -- 500ms debounce
    last_poll = now
    -- Do actual poll
  end
end
```

### Message Diffing

```lua
local function diff_history(old_history, new_history)
  local old_count = #old_history
  local new_count = #new_history

  if new_count > old_count then
    -- New messages
    local new_messages = {}
    for i = old_count + 1, new_count do
      table.insert(new_messages, new_history[i])
    end
    return { type = 'append', messages = new_messages }
  elseif new_count < old_count then
    -- Messages removed (interrupted)
    return { type = 'refresh', history = new_history }
  else
    -- Check for streaming updates
    local last_new = new_history[new_count]
    local last_old = old_history[old_count]

    if last_new.content ~= last_old.content then
      return { type = 'update', message = last_new, index = new_count }
    end
  end

  return { type = 'none' }
end
```

---

## Performance Tips

- **Batch UI updates**: Don't update buffer on every poll, only when state changes
- **Use vim.schedule**: Always wrap UI updates from callbacks
- **Debounce user input**: Don't send every keystroke to server
- **Cache rendered content**: Track what's already in buffer

---

## Common Mistakes

❌ Not wrapping callbacks with `vim.schedule()`
❌ Forgetting to stop polling timer on cleanup
❌ Blocking main thread with synchronous HTTP
❌ Not handling JSON decode errors
❌ Hardcoding port (make it configurable)
❌ Not checking if cn serve is installed

---

## Testing Checklist

```bash
# 1. Check cn serve exists
which cn

# 2. Start manually to test
cn serve --port 8000

# 3. Test endpoints with curl
curl http://localhost:8000/state
curl -X POST -H "Content-Type: application/json" \
  -d '{"message":"test"}' \
  http://localhost:8000/message

# 4. Test in Neovim
nvim -c "lua require('continue').setup()"
:Continue hello
:ContinueHealth
```

---

## Next Steps

1. Implement `lua/continue/process.lua` (spawn/stop cn serve)
2. Implement `lua/continue/client.lua` (HTTP polling)
3. Implement `lua/continue/ui/chat.lua` (render messages)
4. Wire up `lua/continue/commands.lua`
5. Test end-to-end

---

*Keep this open while coding. All patterns are copy-paste ready!*