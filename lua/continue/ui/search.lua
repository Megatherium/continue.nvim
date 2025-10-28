-- Continue.nvim: Search in chat history
-- Implements vim-style search (/ and ?) in chat buffer

local M = {}

local state = {
  search_bufnr = nil,
  search_winnr = nil,
  search_pattern = '',
  matches = {},
  current_match_idx = 0,
  is_searching = false,
  original_cursor = nil,
}

---Find all matches in buffer
---@param bufnr number Buffer to search
---@param pattern string Search pattern
---@return table List of matches {line, col, text}
local function find_matches(bufnr, pattern)
  if not pattern or pattern == '' then
    return {}
  end

  local matches = {}
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  for line_idx, line in ipairs(lines) do
    local col = 1
    while true do
      local start_idx, end_idx = line:find(pattern, col, false)
      if not start_idx then
        break
      end

      table.insert(matches, {
        line = line_idx,
        col = start_idx,
        end_col = end_idx,
        text = line:sub(start_idx, end_idx),
      })

      col = end_idx + 1
    end
  end

  return matches
end

---Highlight all matches
---@param bufnr number Buffer number
---@param matches table List of matches
local function highlight_matches(bufnr, matches)
  local ns_id = vim.api.nvim_create_namespace('continue_search')
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

  for i, match in ipairs(matches) do
    local hl_group = i == state.current_match_idx and 'IncSearch' or 'Search'
    vim.api.nvim_buf_add_highlight(bufnr, ns_id, hl_group, match.line - 1, match.col - 1, match.end_col)
  end
end

---Show search input prompt
---@param chat_bufnr number Chat buffer to search in
---@param forward boolean Search forward (/) or backward (?)
function M.start_search(chat_bufnr, forward)
  state.is_searching = true
  state.search_pattern = ''
  state.matches = {}
  state.current_match_idx = 0

  -- Save current cursor position
  local winnr = vim.fn.bufwinid(chat_bufnr)
  if winnr == -1 then
    return
  end

  state.original_cursor = vim.api.nvim_win_get_cursor(winnr)

  -- Create search input window at bottom of screen
  local width = vim.o.columns
  local height = 1

  if not state.search_bufnr or not vim.api.nvim_buf_is_valid(state.search_bufnr) then
    state.search_bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(state.search_bufnr, 'buftype', 'prompt')
    vim.api.nvim_buf_set_option(state.search_bufnr, 'filetype', 'continue-search')
  end

  local win_config = {
    relative = 'editor',
    width = width - 4,
    height = height,
    row = vim.o.lines - 3,
    col = 2,
    style = 'minimal',
    border = 'single',
    zindex = 150,
  }

  state.search_winnr = vim.api.nvim_open_win(state.search_bufnr, true, win_config)

  -- Set prompt
  local prompt_char = forward and '/' or '?'
  vim.fn.prompt_setprompt(state.search_bufnr, prompt_char)

  -- Set up prompt callback
  vim.fn.prompt_setcallback(state.search_bufnr, function(text)
    M.execute_search(chat_bufnr, text, forward)
  end)

  -- Set up interrupt callback
  vim.fn.prompt_setinterrupt(state.search_bufnr, function()
    M.cancel_search(chat_bufnr)
  end)

  -- Real-time search as user types
  vim.api.nvim_create_autocmd('TextChangedI', {
    buffer = state.search_bufnr,
    callback = function()
      local lines = vim.api.nvim_buf_get_lines(state.search_bufnr, 0, -1, false)
      local query = lines[1] or ''

      if query ~= '' then
        state.matches = find_matches(chat_bufnr, query)
        state.current_match_idx = #state.matches > 0 and 1 or 0
        highlight_matches(chat_bufnr, state.matches)

        -- Jump to first match
        if state.current_match_idx > 0 then
          local match = state.matches[state.current_match_idx]
          vim.api.nvim_win_set_cursor(winnr, { match.line, match.col - 1 })
        end
      end
    end,
  })

  -- Enter insert mode
  vim.cmd('startinsert')
end

---Execute search and close prompt
---@param chat_bufnr number Chat buffer
---@param pattern string Search pattern
---@param forward boolean Forward search (reserved for future bidirectional search)
function M.execute_search(chat_bufnr, pattern, forward)
  _ = forward -- Reserved for future use
  state.search_pattern = pattern
  state.matches = find_matches(chat_bufnr, pattern)
  state.current_match_idx = #state.matches > 0 and 1 or 0

  highlight_matches(chat_bufnr, state.matches)

  -- Show match count
  if #state.matches > 0 then
    vim.notify(string.format('Found %d matches', #state.matches), vim.log.levels.INFO)
  else
    vim.notify('No matches found', vim.log.levels.WARN)
  end

  M.close_search_window()
end

---Cancel search and restore cursor
---@param chat_bufnr number Chat buffer
function M.cancel_search(chat_bufnr)
  -- Clear highlights
  local ns_id = vim.api.nvim_create_namespace('continue_search')
  vim.api.nvim_buf_clear_namespace(chat_bufnr, ns_id, 0, -1)

  -- Restore cursor
  if state.original_cursor then
    local winnr = vim.fn.bufwinid(chat_bufnr)
    if winnr ~= -1 then
      vim.api.nvim_win_set_cursor(winnr, state.original_cursor)
    end
  end

  M.close_search_window()

  state.is_searching = false
  state.matches = {}
  state.current_match_idx = 0
  state.search_pattern = ''
end

---Close search input window
function M.close_search_window()
  if state.search_winnr and vim.api.nvim_win_is_valid(state.search_winnr) then
    vim.api.nvim_win_close(state.search_winnr, true)
  end

  state.search_winnr = nil
end

---Jump to next match
---@param chat_bufnr number Chat buffer
function M.next_match(chat_bufnr)
  if #state.matches == 0 then
    vim.notify('No active search', vim.log.levels.WARN)
    return
  end

  state.current_match_idx = state.current_match_idx + 1
  if state.current_match_idx > #state.matches then
    state.current_match_idx = 1
  end

  local match = state.matches[state.current_match_idx]
  local winnr = vim.fn.bufwinid(chat_bufnr)
  if winnr ~= -1 then
    vim.api.nvim_win_set_cursor(winnr, { match.line, match.col - 1 })
  end

  highlight_matches(chat_bufnr, state.matches)

  vim.notify(string.format('Match %d of %d', state.current_match_idx, #state.matches), vim.log.levels.INFO)
end

---Jump to previous match
---@param chat_bufnr number Chat buffer
function M.prev_match(chat_bufnr)
  if #state.matches == 0 then
    vim.notify('No active search', vim.log.levels.WARN)
    return
  end

  state.current_match_idx = state.current_match_idx - 1
  if state.current_match_idx < 1 then
    state.current_match_idx = #state.matches
  end

  local match = state.matches[state.current_match_idx]
  local winnr = vim.fn.bufwinid(chat_bufnr)
  if winnr ~= -1 then
    vim.api.nvim_win_set_cursor(winnr, { match.line, match.col - 1 })
  end

  highlight_matches(chat_bufnr, state.matches)

  vim.notify(string.format('Match %d of %d', state.current_match_idx, #state.matches), vim.log.levels.INFO)
end

---Clear search highlights
---@param chat_bufnr number Chat buffer
function M.clear_search(chat_bufnr)
  local ns_id = vim.api.nvim_create_namespace('continue_search')
  vim.api.nvim_buf_clear_namespace(chat_bufnr, ns_id, 0, -1)

  state.matches = {}
  state.current_match_idx = 0
  state.search_pattern = ''
  state.is_searching = false
end

return M
