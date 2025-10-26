-- Quick automated test for cn serve integration
-- Run with: nvim --headless +"luafile tests/quick_test.lua" +qa

print("=== Quick Test Suite ===\n")

local test_port = 8000
local failures = 0

-- Test 1: JSON utils
print("Test 1: JSON encode/decode")
local json = require('continue.utils.json')
local test_data = { foo = 'bar', num = 42 }
local encoded, err = json.encode(test_data)
if not encoded or err then
  print("❌ FAIL: JSON encode")
  failures = failures + 1
else
  local decoded, err2 = json.decode(encoded)
  if not decoded or err2 or decoded.foo ~= 'bar' then
    print("❌ FAIL: JSON decode")
    failures = failures + 1
  else
    print("✅ PASS: JSON encode/decode")
  end
end

-- Test 2: HTTP client availability
print("\nTest 2: curl availability")
local http = require('continue.utils.http')
if http.has_curl() then
  print("✅ PASS: curl available")
else
  print("❌ FAIL: curl not found")
  failures = failures + 1
end

-- Test 3: Server health (synchronous)
print("\nTest 3: Server health check")
local handle = io.popen('curl -s http://localhost:' .. test_port .. '/state 2>&1')
local result = handle:read('*a')
handle:close()

if result:match('"isProcessing"') then
  print("✅ PASS: Server responding")
else
  print("❌ FAIL: Server not responding")
  print("  Output: " .. result:sub(1, 100))
  failures = failures + 1
end

-- Test 4: POST message
print("\nTest 4: POST message endpoint")
local post_cmd = [[curl -s -X POST http://localhost:]] .. test_port .. [[/message \
  -H "Content-Type: application/json" \
  -d '{"message":"test"}' 2>&1]]
local handle2 = io.popen(post_cmd)
local result2 = handle2:read('*a')
handle2:close()

if result2:match('"queued"') then
  print("✅ PASS: Message queued")
else
  print("❌ FAIL: Message not queued")
  print("  Output: " .. result2:sub(1, 100))
  failures = failures + 1
end

-- Summary
print("\n=== Test Summary ===")
if failures == 0 then
  print("✅ All tests passed!")
  os.exit(0)
else
  print("❌ " .. failures .. " test(s) failed")
  os.exit(1)
end
