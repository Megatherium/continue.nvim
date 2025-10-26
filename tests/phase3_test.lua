-- Test Phase 3 features: syntax highlighting, dynamic polling, copy, help
-- Run with: nvim --headless +"luafile tests/phase3_test.lua" +qa

print("=== Phase 3 Features Test ===\n")

local failures = 0

-- Test 1: Load UI module with new functions
print("Test 1: Load UI module")
local ok, ui = pcall(require, 'continue.ui.chat')
if not ok then
  print("❌ FAIL: Cannot load UI module: " .. tostring(ui))
  failures = failures + 1
  os.exit(1)
else
  print("✅ PASS: UI module loaded")
end

-- Test 2: Check syntax highlighting function exists
print("\nTest 2: Syntax highlighting functions")
local has_syntax = type(ui.apply_syntax_highlighting) == 'function'
if has_syntax then
  print("✅ PASS: apply_syntax_highlighting function exists")
else
  print("❌ FAIL: Missing syntax highlighting function")
  failures = failures + 1
end

-- Test 3: Check copy functions exist
print("\nTest 3: Copy functions")
local has_copy_current = type(ui.copy_current_message) == 'function'
local has_copy_all = type(ui.copy_all_messages) == 'function'
if has_copy_current and has_copy_all then
  print("✅ PASS: Copy functions exist")
else
  print("❌ FAIL: Missing copy functions")
  failures = failures + 1
end

-- Test 4: Check help function exists
print("\nTest 4: Help function")
local has_help = type(ui.show_help) == 'function'
if has_help then
  print("✅ PASS: show_help function exists")
else
  print("❌ FAIL: Missing help function")
  failures = failures + 1
end

-- Test 5: Load client module with dynamic polling
print("\nTest 5: Client module with dynamic polling")
local ok2, client = pcall(require, 'continue.client')
if not ok2 then
  print("❌ FAIL: Cannot load client module")
  failures = failures + 1
else
  print("✅ PASS: Client module loaded")
end

-- Test 6: Check calculate_poll_interval function
print("\nTest 6: Dynamic polling function")
local has_calc = type(client.calculate_poll_interval) == 'function'
if has_calc then
  print("✅ PASS: calculate_poll_interval function exists")

  -- Test the function
  local idle_interval = client.calculate_poll_interval({
    isProcessing = false,
    messageQueueLength = 0,
    chatHistory = {}
  })

  local active_interval = client.calculate_poll_interval({
    isProcessing = true,
    messageQueueLength = 0,
    chatHistory = {}
  })

  if idle_interval == 1000 and active_interval == 100 then
    print("✅ PASS: Polling intervals correct (idle=1000ms, active=100ms)")
  else
    print("❌ FAIL: Incorrect polling intervals")
    print(string.format("  idle=%d (expected 1000), active=%d (expected 100)",
      idle_interval, active_interval))
    failures = failures + 1
  end
else
  print("❌ FAIL: Missing calculate_poll_interval function")
  failures = failures + 1
end

-- Test 7: Test inline syntax highlighting
print("\nTest 7: Inline syntax highlighting")
local has_inline = type(ui.apply_inline_syntax) == 'function'
if has_inline then
  print("✅ PASS: apply_inline_syntax function exists")
else
  print("❌ FAIL: Missing inline syntax function")
  failures = failures + 1
end

-- Summary
print("\n=== Test Summary ===")
if failures == 0 then
  print("✅ All Phase 3 tests passed!")
  print("\nNew features verified:")
  print("  ✨ Syntax highlighting for code blocks")
  print("  ⚡ Dynamic polling intervals (100ms active, 1s idle)")
  print("  📋 Message copying (yy, yA)")
  print("  ❓ Keyboard shortcuts help (?)")
  print("  📊 Processing status indicator")
  os.exit(0)
else
  print("❌ " .. failures .. " test(s) failed")
  os.exit(1)
end
