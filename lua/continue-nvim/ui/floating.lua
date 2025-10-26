-- Continue.nvim - Floating window utilities
-- Helper functions for creating and managing floating windows

local M = {}

-- Create a centered floating window
function M.create_centered(opts)
  opts = opts or {}

  local width = opts.width or math.floor(vim.o.columns * 0.8)
  local height = opts.height or math.floor(vim.o.lines * 0.8)

  -- Calculate center position
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)

  -- Create window
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = opts.border or 'rounded',
    title = opts.title,
    title_pos = opts.title_pos or 'center',
  })

  -- Set buffer options
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')

  -- Add close keymaps
  local close_keys = opts.close_keys or { 'q', '<Esc>' }
  for _, key in ipairs(close_keys) do
    vim.keymap.set('n', key, function()
      vim.api.nvim_win_close(win, true)
    end, { buffer = buf, silent = true })
  end

  return {
    buf = buf,
    win = win,
    close = function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end
  }
end

-- Create a split window (for chat-like interface)
function M.create_split(opts)
  opts = opts or {}

  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)

  -- Create split
  local cmd = opts.position == 'right' and 'vsplit' or 'split'
  vim.cmd(cmd)
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)

  -- Set window size
  if opts.size then
    if opts.position == 'right' then
      vim.api.nvim_win_set_width(win, opts.size)
    else
      vim.api.nvim_win_set_height(win, opts.size)
    end
  end

  return {
    buf = buf,
    win = win,
    close = function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end
  }
end

return M
