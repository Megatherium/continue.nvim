-- Test Phase 4 features: export and welcome screen
-- Run with: nvim --headless +"luafile tests/phase4_test.lua" +qa

print("=== Phase 4 Features Test ===\n")

local failures = 0

-- Test 1: Load export module
print("Test 1: Load export module")
local ok, export = pcall(require, 'continue.export')
if not ok then
  print("❌ FAIL: Cannot load export module: " .. tostring(export))
  failures = failures + 1
  os.exit(1)
else
  print("✅ PASS: Export module loaded")
end

-- Test 2: Test markdown export function
print("\nTest 2: Markdown export function")
local test_history = {
  {
    role = 'user',
    content = 'Hello, how are you?'
  },
  {
    role = 'assistant',
    content = 'I am doing well, thank you!'
  },
  {
    role = 'user',
    content = 'Write a fibonacci function'
  },
  {
    role = 'assistant',
    content = 'Here is a fibonacci function:\n\n```python\ndef fibonacci(n):\n    if n <= 1:\n        return n\n    return fibonacci(n-1) + fibonacci(n-2)\n```'
  }
}

local markdown = export.to_markdown(test_history)
if markdown and markdown:match('Continue.nvim Chat Export') then
  print("✅ PASS: Markdown export generates valid output")

  -- Check for all expected elements
  local has_header = markdown:match('# Continue.nvim')
  local has_user = markdown:match('## 🧑 You')
  local has_assistant = markdown:match('## 🤖 Assistant')
  local has_code = markdown:match('```python')

  if has_header and has_user and has_assistant and has_code then
    print("✅ PASS: Markdown contains all expected elements")
  else
    print("❌ FAIL: Missing expected markdown elements")
    print("  Header: " .. tostring(has_header ~= nil))
    print("  User: " .. tostring(has_user ~= nil))
    print("  Assistant: " .. tostring(has_assistant ~= nil))
    print("  Code: " .. tostring(has_code ~= nil))
    failures = failures + 1
  end
else
  print("❌ FAIL: Invalid markdown output")
  failures = failures + 1
end

-- Test 3: Test file export
print("\nTest 3: File export")
local test_file = '/tmp/continue_test_export.md'
local success, err = export.to_file(test_history, test_file)

if success then
  print("✅ PASS: Export to file succeeded")

  -- Verify file exists and has content
  local file = io.open(test_file, 'r')
  if file then
    local content = file:read('*all')
    file:close()

    if #content > 100 and content:match('fibonacci') then
      print("✅ PASS: File has correct content")
    else
      print("❌ FAIL: File content incorrect")
      failures = failures + 1
    end

    -- Cleanup
    os.remove(test_file)
  else
    print("❌ FAIL: Could not read exported file")
    failures = failures + 1
  end
else
  print("❌ FAIL: Export to file failed: " .. (err or 'unknown'))
  failures = failures + 1
end

-- Test 4: Test auto export
print("\nTest 4: Auto export with timestamp")
local auto_path, auto_err = export.auto_export(test_history, '/tmp')

if auto_path then
  print("✅ PASS: Auto export succeeded")
  print("  Generated: " .. auto_path)

  -- Verify filename format
  if auto_path:match('continue_chat_%d+_%d+%.md') then
    print("✅ PASS: Filename has correct format")
  else
    print("❌ FAIL: Incorrect filename format")
    failures = failures + 1
  end

  -- Cleanup
  os.remove(auto_path)
else
  print("❌ FAIL: Auto export failed: " .. (auto_err or 'unknown'))
  failures = failures + 1
end

-- Test 5: Test empty history
print("\nTest 5: Empty history handling")
local empty_md = export.to_markdown({})
if empty_md:match('No messages') then
  print("✅ PASS: Empty history handled correctly")
else
  print("❌ FAIL: Empty history not handled")
  failures = failures + 1
end

-- Summary
print("\n=== Test Summary ===")
if failures == 0 then
  print("✅ All Phase 4 tests passed!")
  print("\nNew features verified:")
  print("  📤 Markdown export functionality")
  print("  💾 File export with custom path")
  print("  ⏰ Auto-export with timestamps")
  print("  ✨ Enhanced welcome screen (visual check needed)")
  os.exit(0)
else
  print("❌ " .. failures .. " test(s) failed")
  os.exit(1)
end
