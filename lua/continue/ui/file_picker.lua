-- Continue.nvim: File picker for @ mentions
-- Fuzzy file finder for attaching context to messages

local M = {}

local state = {
  picker_bufnr = nil,
  picker_winnr = nil,
  selected_index = 1,
  filtered_files = {},
  all_files = {},
  is_showing = false,
  attached_files = {}, -- List of attached files for current message
}

---Find all files in the current working directory
---@param callback function(files: table) Callback with file list
local function find_project_files(callback)
  -- Use git ls-files if in a git repo, otherwise use find
  local cmd = 'git ls-files 2>/dev/null || find . -type f -not -path "*/\\.git/*" -not -path "*/node_modules/*" | head -1000'

  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      local files = {}
      for _, line in ipairs(data) do
        if line and line ~= '' then
          table.insert(files, line)
        end
      end

      vim.schedule(function()
        callback(files)
      end)
    end,
  })
end

---Fuzzy match files
---@param filter string Search filter
---@param files table All files
---@return table Matched files
local function fuzzy_match_files(filter, files)
  if not filter or filter == '' then
    return vim.list_slice(files, 1, 20) -- Return first 20
  end

  local filter_lower = filter:lower()
  local matches = {}

  for _, file in ipairs(files) do
    local file_lower = file:lower()
    local score = 0

    -- Exact match (very high)
    if file_lower == filter_lower then
      score = 10000
    -- Basename exact match (high)
    elseif vim.fn.fnamemodify(file, ':t'):lower() == filter_lower then
      score = 5000
    -- Starts with filter (high)
    elseif vim.startswith(file_lower, filter_lower) then
      score = 1000
    -- Basename starts with (medium-high)
    elseif vim.startswith(vim.fn.fnamemodify(file, ':t'):lower(), filter_lower) then
      score = 500
    -- Contains in basename (medium)
    elseif vim.fn.fnamemodify(file, ':t'):lower():find(filter_lower, 1, true) then
      score = 100
    -- Contains anywhere (low)
    elseif file_lower:find(filter_lower, 1, true) then
      score = 50
    end

    if score > 0 then
      table.insert(matches, {
        file = file,
        score = score,
      })
    end
  end

  -- Sort by score
  table.sort(matches, function(a, b)
    return a.score > b.score
  end)

  -- Extract files
  local result = {}
  for i, match in ipairs(matches) do
    if i > 20 then
      break
    end
    table.insert(result, match.file)
  end

  return result
end

---Show file picker
---@param anchor_winnr number Window to anchor to
---@param filter string Filter text (without @)
function M.show(anchor_winnr, filter)
  -- Lazy load files on first show
  if #state.all_files == 0 then
    find_project_files(function(files)
      state.all_files = files
      M.show(anchor_winnr, filter)
    end)
    return
  end

  -- Filter files
  state.filtered_files = fuzzy_match_files(filter, state.all_files)

  if #state.filtered_files == 0 then
    M.hide()
    return
  end

  -- Reset selection if needed
  if state.selected_index > #state.filtered_files then
    state.selected_index = 1
  end

  -- Create picker buffer if needed
  if not state.picker_bufnr or not vim.api.nvim_buf_is_valid(state.picker_bufnr) then
    state.picker_bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(state.picker_bufnr, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(state.picker_bufnr, 'filetype', 'continue-files')
  end

  -- Calculate dimensions
  local max_files = math.min(15, #state.filtered_files)
  local max_width = 100
  local height = max_files + 3 -- +3 for header, footer, attached files

  -- Get anchor position
  local anchor_ok, anchor_info = pcall(vim.api.nvim_win_get_config, anchor_winnr)
  if not anchor_ok then
    M.hide()
    return
  end

  -- Position above input window
  local row = 0
  local col = 0

  if anchor_info.relative == 'editor' then
    row = anchor_info.row - height - 1
    col = anchor_info.col

    if row < 0 then
      row = anchor_info.row + anchor_info.height + 1
    end
  end

  local win_config = {
    relative = 'editor',
    width = max_width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    zindex = 100,
  }

  -- Open or update window
  if state.picker_winnr and vim.api.nvim_win_is_valid(state.picker_winnr) then
    vim.api.nvim_win_set_config(state.picker_winnr, win_config)
  else
    state.picker_winnr = vim.api.nvim_open_win(state.picker_bufnr, false, win_config)
    vim.api.nvim_win_set_option(state.picker_winnr, 'winblend', 10)
  end

  -- Render
  M.render()

  state.is_showing = true
end

---Render file picker
function M.render()
  if not state.picker_bufnr or not vim.api.nvim_buf_is_valid(state.picker_bufnr) then
    return
  end

  local lines = {}
  local highlights = {}

  -- Header
  table.insert(lines, string.format('  📎 Attach Files (%d)', #state.filtered_files))
  table.insert(highlights, { line = 0, hl_group = 'Title' })

  -- Attached files indicator
  if #state.attached_files > 0 then
    local attached_str = string.format('  Attached: %d file(s)', #state.attached_files)
    table.insert(lines, attached_str)
    table.insert(highlights, { line = 1, hl_group = 'String' })
  end

  -- Files
  for i, file in ipairs(state.filtered_files) do
    if i > 15 then
      break
    end

    local is_selected = i == state.selected_index
    local is_attached = vim.tbl_contains(state.attached_files, file)

    local icon = is_attached and '✓' or ' '
    local line = string.format('%s %s', icon, file)

    if is_selected then
      line = '▶' .. line:sub(2)
    end

    table.insert(lines, line)

    if is_selected then
      table.insert(highlights, { line = #lines - 1, hl_group = 'PmenuSel' })
    elseif is_attached then
      table.insert(highlights, { line = #lines - 1, hl_group = 'String' })
    end
  end

  -- Footer
  table.insert(lines, '  ↑/↓:navigate  Tab:attach  Enter:attach&close  Esc:cancel')
  table.insert(highlights, { line = #lines - 1, hl_group = 'Comment' })

  -- Set content
  vim.api.nvim_buf_set_option(state.picker_bufnr, 'modifiable', true)
  vim.api.nvim_buf_set_lines(state.picker_bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(state.picker_bufnr, 'modifiable', false)

  -- Apply highlights
  local ns_id = vim.api.nvim_create_namespace('continue_file_picker')
  vim.api.nvim_buf_clear_namespace(state.picker_bufnr, ns_id, 0, -1)

  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(state.picker_bufnr, ns_id, hl.hl_group, hl.line, 0, -1)
  end
end

---Hide picker
function M.hide()
  if state.picker_winnr and vim.api.nvim_win_is_valid(state.picker_winnr) then
    vim.api.nvim_win_close(state.picker_winnr, true)
  end

  state.picker_winnr = nil
  state.is_showing = false
  state.filtered_files = {}
  state.selected_index = 1
end

---Navigate up
function M.navigate_up()
  if #state.filtered_files == 0 then
    return
  end

  state.selected_index = state.selected_index - 1
  if state.selected_index < 1 then
    state.selected_index = #state.filtered_files
  end

  M.render()
end

---Navigate down
function M.navigate_down()
  if #state.filtered_files == 0 then
    return
  end

  state.selected_index = state.selected_index + 1
  if state.selected_index > #state.filtered_files then
    state.selected_index = 1
  end

  M.render()
end

---Toggle attachment of selected file
function M.toggle_selected()
  if #state.filtered_files == 0 then
    return
  end

  local selected_file = state.filtered_files[state.selected_index]

  -- Toggle attachment
  local idx = nil
  for i, file in ipairs(state.attached_files) do
    if file == selected_file then
      idx = i
      break
    end
  end

  if idx then
    table.remove(state.attached_files, idx)
  else
    table.insert(state.attached_files, selected_file)
  end

  M.render()
end

---Attach selected file and close
---@param input_bufnr number Input buffer
function M.attach_and_close(input_bufnr)
  M.toggle_selected()

  -- Update input buffer with file context
  local lines = vim.api.nvim_buf_get_lines(input_bufnr, 0, -1, false)
  local current_line = lines[1] or ''

  -- Remove the @ mention
  local new_line = current_line:gsub('@[^%s]*', ''):gsub('^%s+', '')

  -- Prepend file mentions
  if #state.attached_files > 0 then
    local file_mentions = {}
    for _, file in ipairs(state.attached_files) do
      table.insert(file_mentions, '@' .. file)
    end
    new_line = table.concat(file_mentions, ' ') .. ' ' .. new_line
  end

  vim.api.nvim_buf_set_lines(input_bufnr, 0, 1, false, { new_line })

  -- Move cursor to end
  vim.schedule(function()
    local winnr = vim.fn.bufwinid(input_bufnr)
    if winnr ~= -1 then
      vim.api.nvim_win_set_cursor(winnr, { 1, #new_line })
    end
  end)

  M.hide()
end

---Check if picker is visible
---@return boolean
function M.is_visible()
  return state.is_showing
end

---Clear attached files
function M.clear_attached()
  state.attached_files = {}
end

return M
