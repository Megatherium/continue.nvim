-- Test actual plugin functionality
-- Tests client API, process management, UI

print("=== Plugin Function Tests ===\n")

local test_port = 8000
local failures = 0

-- Test 1: Client module loads
print("Test 1: Load client module")
local ok, client = pcall(require, 'continue.client')
if not ok then
  print("❌ FAIL: Cannot load client module: " .. tostring(client))
  failures = failures + 1
  os.exit(1)
else
  print("✅ PASS: Client module loaded")
end

-- Test 2: Process module loads
print("\nTest 2: Load process module")
local ok2, process = pcall(require, 'continue.process')
if not ok2 then
  print("❌ FAIL: Cannot load process module: " .. tostring(process))
  failures = failures + 1
else
  print("✅ PASS: Process module loaded")
end

-- Test 3: UI module loads
print("\nTest 3: Load UI module")
local ok3, ui = pcall(require, 'continue.ui.chat')
if not ok3 then
  print("❌ FAIL: Cannot load UI module: " .. tostring(ui))
  failures = failures + 1
else
  print("✅ PASS: UI module loaded")
end

-- Test 4: Client status
print("\nTest 4: Client status")
local status = client.status()
if status and type(status.polling) == 'boolean' then
  print("✅ PASS: Client status returns valid data")
  print("  polling: " .. tostring(status.polling))
else
  print("❌ FAIL: Invalid client status")
  failures = failures + 1
end

-- Test 5: Message formatting
print("\nTest 5: Message formatting")
local msg = {
  role = 'user',
  content = 'Hello world',
}
local lines = ui.format_message(msg)
if lines and #lines > 0 and lines[1]:match('You:') then
  print("✅ PASS: Message formatting works")
  print("  Formatted: " .. lines[1])
else
  print("❌ FAIL: Message formatting failed")
  failures = failures + 1
end

-- Test 6: Tool message formatting
print("\nTest 6: Tool message formatting")
local tool_msg = {
  messageType = 'tool-start',
  toolName = 'Read',
}
local tool_lines = ui.format_message(tool_msg)
if tool_lines and #tool_lines > 0 and tool_lines[1]:match('Tool:') then
  print("✅ PASS: Tool formatting works")
  print("  Formatted: " .. tool_lines[1])
else
  print("❌ FAIL: Tool formatting failed")
  failures = failures + 1
end

-- Summary
print("\n=== Test Summary ===")
if failures == 0 then
  print("✅ All plugin tests passed!")
  os.exit(0)
else
  print("❌ " .. failures .. " test(s) failed")
  os.exit(1)
end
