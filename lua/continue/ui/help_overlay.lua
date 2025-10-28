-- Continue.nvim: Help overlay
-- Shows keyboard shortcuts and available commands

local M = {}

local state = {
  help_bufnr = nil,
  help_winnr = nil,
  is_showing = false,
}

---Generate help content
---@return table Lines of help text
local function generate_help_content()
  local lines = {
    '',
    '╔══════════════════════════════════════════════════════════════════════════╗',
    '║                    Continue.nvim Keyboard Shortcuts                     ║',
    '╚══════════════════════════════════════════════════════════════════════════╝',
    '',
    '  CHAT WINDOW',
    '  ──────────────────────────────────────────────────────────────────────',
    '    q / <Esc>         Close chat window',
    '    g?                Show this help screen',
    '    yy                Copy current message to clipboard',
    '    yA                Copy all messages to clipboard',
    '    <C-w>=            Reset window size to default',
    '    <C-w>+/-          Increase/decrease window height',
    '    <C-w></>          Increase/decrease window width',
    '',
    '  SEARCH IN CHAT',
    '  ──────────────────────────────────────────────────────────────────────',
    '    /                 Start forward search (vim-style)',
    '    n                 Jump to next match',
    '    N                 Jump to previous match',
    '    <C-l>             Clear search highlights',
    '',
    '  CODE BLOCK OPERATIONS',
    '  ──────────────────────────────────────────────────────────────────────',
    '    yc                Yank (copy) code block at cursor',
    '    ]c                Jump to next code block',
    '    [c                Jump to previous code block',
    '    <leader>ce        Execute code block (Lua, Vim, Bash, Python)',
    '    <leader>cw        Write code block to file',
    '',
    '  INPUT AREA',
    '  ──────────────────────────────────────────────────────────────────────',
    '    i / a             Start typing (insert mode)',
    '    <CR>              Send message (insert or normal mode)',
    '    <Esc>             Cancel input / hide suggestions',
    '',
    '  SLASH COMMANDS (type / to trigger autocomplete)',
    '  ──────────────────────────────────────────────────────────────────────',
    '    /help             Show help message in chat',
    '    /clear            Clear chat history (local)',
    '    /model            Switch AI model',
    '    /config           Switch configuration',
    '    /mcp              Manage MCP servers',
    '    /compact          Summarize chat history',
    '    /info             Show session information',
    '    /resume           Resume a previous session',
    '    /fork             Fork current conversation',
    '    /title <text>     Set session title',
    '    /exit             Exit chat (local)',
    '',
    '    ↑/↓               Navigate command suggestions',
    '    Tab               Complete selected command',
    '    <Esc>             Hide suggestions',
    '',
    '  FILE ATTACHMENT (type @ to trigger autocomplete)',
    '  ──────────────────────────────────────────────────────────────────────',
    '    @<filename>       Attach file for context (fuzzy finder)',
    '    @path/to/file     Attach specific file path',
    '',
    '    ↑/↓               Navigate file suggestions',
    '    Tab               Toggle file selection',
    '    <Esc>             Cancel file picker',
    '',
    '  CONTINUE COMMANDS',
    '  ──────────────────────────────────────────────────────────────────────',
    '    :Continue [msg]   Open chat or send message',
    '    :ContinueStart    Start Continue server manually',
    '    :ContinueStop     Stop server',
    '    :ContinuePause    Interrupt current AI execution',
    '    :ContinueStatus   Show server status',
    '    :ContinueDiff     Show git diff',
    '    :ContinueHealth   Run health check',
    '    :ContinueExport   Export chat to markdown',
    '',
    '  TIPS & TRICKS',
    '  ──────────────────────────────────────────────────────────────────────',
    '    • Attach multiple files: @file1.lua @file2.lua Message text here',
    '    • Use Tab to quickly complete commands and filenames',
    '    • Search with / works like vim search (/, n, N, <C-l>)',
    '    • Jump between code blocks with ]c and [c',
    '    • Yank code blocks directly with yc (no need to visual select)',
    '    • Execute safe code blocks (Lua/Vim/Bash/Python) with <leader>ce',
    '    • Slash commands work exactly like the Continue CLI',
    '    • Message history persists during the session',
    '    • Export conversations with :ContinueExport for documentation',
    '',
    '  ARCHITECTURE',
    '  ──────────────────────────────────────────────────────────────────────',
    '    Continue.nvim is a lightweight HTTP client that connects to',
    '    `cn serve` (Continue CLI backend). All AI processing happens',
    '    server-side, keeping the plugin thin and always up-to-date.',
    '',
    '  NEW IN THIS BUILD',
    '  ──────────────────────────────────────────────────────────────────────',
    '    ✨ Slash command autocomplete with fuzzy matching',
    '    ✨ @ file attachment with fuzzy finder (git ls-files)',
    '    ✨ Vim-style search in chat history (/, n, N)',
    '    ✨ Code block extraction and execution',
    '    ✨ Enhanced keyboard shortcuts and help overlay',
    '    ✨ Local slash command handlers (/clear, /help, /exit)',
    '',
    '    Press any key to close this help screen',
    '',
  }

  return lines
end

---Show help overlay
function M.show()
  if state.is_showing then
    M.hide()
    return
  end

  -- Create help buffer
  if not state.help_bufnr or not vim.api.nvim_buf_is_valid(state.help_bufnr) then
    state.help_bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(state.help_bufnr, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(state.help_bufnr, 'filetype', 'continue-help')
    vim.api.nvim_buf_set_option(state.help_bufnr, 'modifiable', false)
  end

  -- Calculate dimensions (80% of screen)
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.85)

  local win_config = {
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = 'minimal',
    border = 'rounded',
    zindex = 200, -- Higher than other overlays
  }

  -- Open window
  state.help_winnr = vim.api.nvim_open_win(state.help_bufnr, true, win_config)
  vim.api.nvim_win_set_option(state.help_winnr, 'winblend', 0)

  -- Set content
  local content = generate_help_content()
  vim.api.nvim_buf_set_option(state.help_bufnr, 'modifiable', true)
  vim.api.nvim_buf_set_lines(state.help_bufnr, 0, -1, false, content)
  vim.api.nvim_buf_set_option(state.help_bufnr, 'modifiable', false)

  -- Add syntax highlighting
  M.apply_highlights()

  -- Set up keymaps to close on any key
  local close_keys = {
    'q',
    '<Esc>',
    '<CR>',
    'g?',
    '<Space>',
    '<C-c>',
  }

  for _, key in ipairs(close_keys) do
    vim.keymap.set('n', key, function()
      M.hide()
    end, { buffer = state.help_bufnr, nowait = true })
  end

  state.is_showing = true
end

---Apply syntax highlighting to help buffer
function M.apply_highlights()
  if not state.help_bufnr or not vim.api.nvim_buf_is_valid(state.help_bufnr) then
    return
  end

  local ns_id = vim.api.nvim_create_namespace('continue_help')
  vim.api.nvim_buf_clear_namespace(state.help_bufnr, ns_id, 0, -1)

  local lines = vim.api.nvim_buf_get_lines(state.help_bufnr, 0, -1, false)

  for i, line in ipairs(lines) do
    local line_idx = i - 1

    -- Title (lines with ╔ or ║)
    if line:match('╔') or line:match('║.*║') then
      vim.api.nvim_buf_add_highlight(state.help_bufnr, ns_id, 'Title', line_idx, 0, -1)
    -- Section headers (lines with uppercase and dashes)
    elseif line:match('^  [A-Z]') and not line:match('    ') then
      vim.api.nvim_buf_add_highlight(state.help_bufnr, ns_id, 'Function', line_idx, 0, -1)
    -- Separator lines
    elseif line:match('──') then
      vim.api.nvim_buf_add_highlight(state.help_bufnr, ns_id, 'Comment', line_idx, 0, -1)
    -- Key bindings (lines starting with spaces and having a key)
    elseif line:match('^    %S') then
      -- Highlight the key part (before the description)
      local key_end = line:find('%s%s+')
      if key_end then
        vim.api.nvim_buf_add_highlight(state.help_bufnr, ns_id, 'String', line_idx, 0, key_end)
      end
    -- Slash commands
    elseif line:match('/') then
      local slash_start, slash_end = line:find('/%S+')
      if slash_start then
        vim.api.nvim_buf_add_highlight(state.help_bufnr, ns_id, 'Keyword', line_idx, slash_start - 1, slash_end)
      end
    -- @ mentions
    elseif line:match('@') then
      local at_start, at_end = line:find('@%S+')
      if at_start then
        vim.api.nvim_buf_add_highlight(state.help_bufnr, ns_id, 'Type', line_idx, at_start - 1, at_end)
      end
    -- Continue commands
    elseif line:match(':Continue%S*') then
      local cmd_start, cmd_end = line:find(':Continue%S*')
      if cmd_start then
        vim.api.nvim_buf_add_highlight(state.help_bufnr, ns_id, 'Special', line_idx, cmd_start - 1, cmd_end)
      end
    end
  end
end

---Hide help overlay
function M.hide()
  if state.help_winnr and vim.api.nvim_win_is_valid(state.help_winnr) then
    vim.api.nvim_win_close(state.help_winnr, true)
  end

  state.help_winnr = nil
  state.is_showing = false
end

---Toggle help overlay
function M.toggle()
  if state.is_showing then
    M.hide()
  else
    M.show()
  end
end

return M