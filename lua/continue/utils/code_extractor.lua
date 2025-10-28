-- Continue.nvim: Code block extraction utilities
-- Extract and manipulate code blocks from markdown messages

local M = {}

---Extract all code blocks from buffer
---@param bufnr number Buffer number
---@return table List of code blocks {start_line, end_line, language, code}
function M.extract_code_blocks(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local blocks = {}
  local in_block = false
  local block_start = nil
  local block_lang = nil
  local block_lines = {}

  for i, line in ipairs(lines) do
    -- Start of code block
    if line:match('^```') and not in_block then
      in_block = true
      block_start = i
      block_lang = line:match('^```(%S+)') or 'text'
      block_lines = {}
    -- End of code block
    elseif line:match('^```') and in_block then
      in_block = false
      table.insert(blocks, {
        start_line = block_start,
        end_line = i,
        language = block_lang,
        code = table.concat(block_lines, '\n'),
      })
      block_start = nil
      block_lang = nil
      block_lines = {}
    -- Inside code block
    elseif in_block then
      table.insert(block_lines, line)
    end
  end

  return blocks
end

---Find code block at cursor position
---@param bufnr number Buffer number
---@param cursor_line number Cursor line number (1-indexed)
---@return table? Code block or nil
function M.get_code_block_at_cursor(bufnr, cursor_line)
  local blocks = M.extract_code_blocks(bufnr)

  for _, block in ipairs(blocks) do
    if cursor_line >= block.start_line and cursor_line <= block.end_line then
      return block
    end
  end

  return nil
end

---Get the next code block after cursor
---@param bufnr number Buffer number
---@param cursor_line number Cursor line number (1-indexed)
---@return table? Code block or nil
function M.get_next_code_block(bufnr, cursor_line)
  local blocks = M.extract_code_blocks(bufnr)

  for _, block in ipairs(blocks) do
    if block.start_line > cursor_line then
      return block
    end
  end

  return nil
end

---Get the previous code block before cursor
---@param bufnr number Buffer number
---@param cursor_line number Cursor line number (1-indexed)
---@return table? Code block or nil
function M.get_prev_code_block(bufnr, cursor_line)
  local blocks = M.extract_code_blocks(bufnr)

  -- Iterate in reverse
  for i = #blocks, 1, -1 do
    local block = blocks[i]
    if block.end_line < cursor_line then
      return block
    end
  end

  return nil
end

---Copy code block to clipboard
---@param block table Code block
function M.copy_block_to_clipboard(block)
  if not block or not block.code then
    vim.notify('No code block found', vim.log.levels.WARN)
    return
  end

  -- Copy to clipboard using vim's clipboard
  vim.fn.setreg('+', block.code)
  vim.fn.setreg('"', block.code)

  local lines_count = select(2, block.code:gsub('\n', '\n')) + 1
  vim.notify(
    string.format('Copied %d lines of %s code to clipboard', lines_count, block.language),
    vim.log.levels.INFO
  )
end

---Write code block to a new file
---@param block table Code block
function M.write_block_to_file(block)
  if not block or not block.code then
    vim.notify('No code block found', vim.log.levels.WARN)
    return
  end

  -- Prompt for filename
  local default_ext = block.language == 'text' and 'txt' or block.language
  local default_name = 'code_snippet.' .. default_ext

  vim.ui.input({
    prompt = 'Save code block to file: ',
    default = default_name,
  }, function(filename)
    if not filename or filename == '' then
      return
    end

    -- Write to file
    local file = io.open(filename, 'w')
    if not file then
      vim.notify('Failed to open file: ' .. filename, vim.log.levels.ERROR)
      return
    end

    file:write(block.code)
    file:close()

    vim.notify(string.format('Code saved to %s', filename), vim.log.levels.INFO)

    -- Ask if user wants to open it
    vim.ui.select({ 'Yes', 'No' }, {
      prompt = 'Open file in editor?',
    }, function(choice)
      if choice == 'Yes' then
        vim.cmd('edit ' .. filename)
      end
    end)
  end)
end

---Execute code block (for safe languages)
---@param block table Code block
function M.execute_block(block)
  if not block or not block.code then
    vim.notify('No code block found', vim.log.levels.WARN)
    return
  end

  -- Only allow safe languages
  local safe_languages = {
    lua = 'lua',
    vim = 'vim',
    sh = 'bash',
    bash = 'bash',
    python = 'python3',
  }

  local interpreter = safe_languages[block.language]
  if not interpreter then
    vim.notify(
      string.format('Execution not supported for %s code blocks', block.language),
      vim.log.levels.WARN
    )
    return
  end

  -- Confirm execution
  vim.ui.select({ 'Yes', 'No' }, {
    prompt = string.format('Execute %s code block?', block.language),
  }, function(choice)
    if choice ~= 'Yes' then
      return
    end

    -- Execute based on language
    if block.language == 'lua' then
      -- Execute Lua directly
      local chunk, err = loadstring(block.code)
      if chunk then
        local success, result = pcall(chunk)
        if success then
          vim.notify('Lua code executed successfully', vim.log.levels.INFO)
          if result then
            print(vim.inspect(result))
          end
        else
          vim.notify('Lua execution error: ' .. tostring(result), vim.log.levels.ERROR)
        end
      else
        vim.notify('Lua syntax error: ' .. tostring(err), vim.log.levels.ERROR)
      end
    elseif block.language == 'vim' then
      -- Execute Vim script
      local success, err_msg = pcall(vim.cmd, block.code)
      if success then
        vim.notify('Vim script executed successfully', vim.log.levels.INFO)
      else
        vim.notify('Vim script error: ' .. tostring(err_msg), vim.log.levels.ERROR)
      end
    else
      -- Execute via shell
      local temp_file = vim.fn.tempname()
      local file = io.open(temp_file, 'w')
      if file then
        file:write(block.code)
        file:close()

        local cmd = string.format('%s %s', interpreter, temp_file)
        local output = vim.fn.system(cmd)

        if vim.v.shell_error == 0 then
          vim.notify('Code executed successfully', vim.log.levels.INFO)
          if output and output ~= '' then
            print(output)
          end
        else
          vim.notify('Execution error:\n' .. output, vim.log.levels.ERROR)
        end

        os.remove(temp_file)
      end
    end
  end)
end

return M
