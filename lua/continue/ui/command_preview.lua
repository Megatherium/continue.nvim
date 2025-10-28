-- Continue.nvim: Command preview/autocomplete UI
-- Shows slash command suggestions in a floating window

local M = {}

local state = {
  preview_bufnr = nil,
  preview_winnr = nil,
  selected_index = 1,
  filtered_commands = {},
  is_showing = false,
}

---Show command preview floating window
---@param anchor_winnr number Window to anchor the preview to
---@param filter string Filter text (without leading /)
function M.show(anchor_winnr, filter)
  local commands_cache = require('continue.commands_cache')

  -- Get filtered commands
  state.filtered_commands = commands_cache.fuzzy_find(filter or '')

  if #state.filtered_commands == 0 then
    M.hide()
    return
  end

  -- Reset selection if out of bounds
  if state.selected_index > #state.filtered_commands then
    state.selected_index = 1
  end

  -- Create preview buffer if needed
  if not state.preview_bufnr or not vim.api.nvim_buf_is_valid(state.preview_bufnr) then
    state.preview_bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(state.preview_bufnr, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(state.preview_bufnr, 'filetype', 'continue-commands')
  end

  -- Calculate dimensions
  local max_commands = math.min(10, #state.filtered_commands)
  local max_width = 80
  local height = max_commands + 2 -- +2 for header and footer

  -- Get cursor position in the anchor window
  local anchor_ok, anchor_info = pcall(vim.api.nvim_win_get_config, anchor_winnr)
  if not anchor_ok then
    M.hide()
    return
  end

  -- Position preview window above or below the input window
  local row = 0
  local col = 0

  if anchor_info.relative == 'editor' then
    -- Floating window - position above it
    row = anchor_info.row - height - 1
    col = anchor_info.col

    -- If would go off top of screen, show below instead
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
  if state.preview_winnr and vim.api.nvim_win_is_valid(state.preview_winnr) then
    vim.api.nvim_win_set_config(state.preview_winnr, win_config)
  else
    state.preview_winnr = vim.api.nvim_open_win(state.preview_bufnr, false, win_config)
    vim.api.nvim_win_set_option(state.preview_winnr, 'winblend', 10)
  end

  -- Render commands
  M.render()

  state.is_showing = true
end

---Render commands to the preview buffer
function M.render()
  if not state.preview_bufnr or not vim.api.nvim_buf_is_valid(state.preview_bufnr) then
    return
  end

  local lines = {}
  local highlights = {}

  -- Header
  table.insert(lines, string.format('  Slash Commands (%d)', #state.filtered_commands))
  table.insert(highlights, { line = 0, hl_group = 'Title' })

  -- Find max name length for alignment
  local max_name_len = 0
  for _, cmd in ipairs(state.filtered_commands) do
    max_name_len = math.max(max_name_len, #cmd.name)
  end

  -- Commands (show up to 10)
  for i, cmd in ipairs(state.filtered_commands) do
    if i > 10 then
      break
    end

    local is_selected = i == state.selected_index
    local icon = cmd.category == 'system' and '⚙' or '🤖'
    local name_padded = string.format('%-' .. max_name_len .. 's', cmd.name)

    local line = string.format('  %s /%s  %s', icon, name_padded, cmd.description)

    if is_selected then
      line = '▶ ' .. line:sub(3)
    end

    table.insert(lines, line)

    if is_selected then
      table.insert(highlights, { line = i, hl_group = 'PmenuSel' })
    end
  end

  -- Footer
  table.insert(lines, '  ↑/↓:navigate  Tab:complete  Esc:cancel')
  table.insert(highlights, { line = #lines - 1, hl_group = 'Comment' })

  -- Set buffer content
  vim.api.nvim_buf_set_option(state.preview_bufnr, 'modifiable', true)
  vim.api.nvim_buf_set_lines(state.preview_bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(state.preview_bufnr, 'modifiable', false)

  -- Apply highlights
  local ns_id = vim.api.nvim_create_namespace('continue_command_preview')
  vim.api.nvim_buf_clear_namespace(state.preview_bufnr, ns_id, 0, -1)

  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(state.preview_bufnr, ns_id, hl.hl_group, hl.line, 0, -1)
  end
end

---Hide the preview window
function M.hide()
  if state.preview_winnr and vim.api.nvim_win_is_valid(state.preview_winnr) then
    vim.api.nvim_win_close(state.preview_winnr, true)
  end

  state.preview_winnr = nil
  state.is_showing = false
  state.filtered_commands = {}
  state.selected_index = 1
end

---Navigate selection up
function M.navigate_up()
  if #state.filtered_commands == 0 then
    return
  end

  state.selected_index = state.selected_index - 1
  if state.selected_index < 1 then
    state.selected_index = #state.filtered_commands
  end

  M.render()
end

---Navigate selection down
function M.navigate_down()
  if #state.filtered_commands == 0 then
    return
  end

  state.selected_index = state.selected_index + 1
  if state.selected_index > #state.filtered_commands then
    state.selected_index = 1
  end

  M.render()
end

---Get the currently selected command
---@return table? Selected command or nil
function M.get_selected()
  if #state.filtered_commands == 0 then
    return nil
  end

  return state.filtered_commands[state.selected_index]
end

---Check if preview is currently showing
---@return boolean
function M.is_visible()
  return state.is_showing
end

---Complete the selected command in the input buffer
---@param input_bufnr number Input buffer number
function M.complete_selected(input_bufnr)
  local selected = M.get_selected()
  if not selected then
    return
  end

  -- Replace /filter with /command
  local new_line = '/' .. selected.name .. ' '

  -- Set new line
  vim.api.nvim_buf_set_lines(input_bufnr, 0, 1, false, { new_line })

  -- Move cursor to end
  vim.schedule(function()
    local input_winnr = vim.fn.bufwinid(input_bufnr)
    if input_winnr ~= -1 then
      vim.api.nvim_win_set_cursor(input_winnr, { 1, #new_line })
    end
  end)

  -- Hide preview
  M.hide()
end

return M
