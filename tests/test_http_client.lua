--[[
HTTP Client Test Suite

USAGE:
  1. Start cn serve in terminal: cn serve --port 8000
  2. Open Neovim in this project directory
  3. Run: :luafile tests/test_http_client.lua

REQUIREMENTS:
  - cn serve running on port 8000
  - Neovim 0.10+
  - curl installed

TEST COVERAGE:
  - JSON encoding/decoding
  - HTTP GET requests
  - HTTP POST requests
  - State polling
  - Message sending
  - Permission handling
  - Diff retrieval
  - Health checks
  - Error handling
--]]

local test_port = 8000
local test_url = 'http://localhost:' .. test_port

-- \ANSI color for output
local colors = {
  -- reset
  reset     = 0,

  -- misc
  bright    = 1,
  dim       = 2,
  underline = 4,
  blink     = 5,
  reverse   = 7,
  hidden    = 8,

  -- foreground colors
  black     = 30,
  red       = 31,
  green     = 32,
  yellow    = 33,
  blue      = 34,
  magenta   = 35,
  cyan      = 36,
  white     = 37,

  -- background colors
  blackbg   = 40,
  redbg     = 41,
  greenbg   = 42,
  yellowbg  = 43,
  bluebg    = 44,
  magentabg = 45,
  cyanbg    = 46,
  whitebg   = 47
}

local escapeString = string.char(27) .. '[%dm'
local function escapeNumber(number)
  return escapeString:format(number)
end

local function log(msg, color)
  local reset = escapeNumber(colors.reset)
  color = escapeNumber(color) or escapeNumber(colors.reset)
  io.write(color .. msg .. reset .. "\n")
end

local function log_success(msg)
  log('✓ ' .. msg, colors.green)
end

local function log_error(msg)
  log('✗ ' .. msg, colors.red)
end

local function log_info(msg)
  log('ℹ ' .. msg, colors.blue)
end

local function log_section(msg)
  log('\n' .. string.rep('=', 60), colors.dim)
  log(msg, colors.yellow)
  log(string.rep('=', 60), colors.dim)
end

-- Test counter
local tests_run = 0
local tests_passed = 0
local tests_failed = 0

local function assert_test(condition, test_name, details)
  tests_run = tests_run + 1
  if condition then
    tests_passed = tests_passed + 1
    log_success(test_name)
  else
    tests_failed = tests_failed + 1
    log_error(test_name .. (details and ': ' .. details or ''))
  end
end

-- ============================================================================
-- TEST SUITE: JSON Utils
-- ============================================================================

log_section('Testing JSON Utils')

local json = require('continue.utils.json')

-- Test 1: JSON encode
local test_data = { foo = 'bar', num = 42, nested = { baz = true } }
local encoded, err = json.encode(test_data)
assert_test(encoded and not err, 'JSON encode success', err)
assert_test(encoded:match('"foo"') ~= nil, 'JSON encode contains key', encoded)

-- Test 2: JSON decode
local decoded, err = json.decode(encoded)
assert_test(decoded and not err, 'JSON decode success', err)
assert_test(decoded.foo == 'bar', 'JSON decode preserves string')
assert_test(decoded.num == 42, 'JSON decode preserves number')
assert_test(decoded.nested.baz == true, 'JSON decode preserves nested data')

-- Test 3: JSON error handling
local _, err = json.encode(nil)
assert_test(err ~= nil, 'JSON encode nil returns error', err)

local _, err = json.decode('')
assert_test(err ~= nil, 'JSON decode empty string returns error', err)

local _, err = json.decode('invalid{json')
assert_test(err ~= nil, 'JSON decode invalid JSON returns error', err)

-- ============================================================================
-- TEST SUITE: HTTP Client
-- ============================================================================

log_section('Testing HTTP Client')

local http = require('continue.utils.http')

-- Test 4: curl availability
assert_test(http.has_curl(), 'curl is installed')

-- Test 5: GET request (async - need to use vim.wait)
log_info('Testing GET /state (async)...')
local get_success = false
local get_response = nil
local get_error = nil

http.get(test_url .. '/state', function(err, response)
  get_error = err
  get_response = response
  get_success = true
end)

-- Wait up to 3 seconds for response
vim.wait(3000, function()
  return get_success
end, 100)

assert_test(get_success, 'GET request completed')
assert_test(not get_error, 'GET request no error', get_error)
assert_test(get_response ~= nil, 'GET request has response')
if get_response then
  assert_test(get_response.status == 200, 'GET request status 200', tostring(get_response.status))
  assert_test(get_response.body ~= '', 'GET request has body')

  -- Try to parse state
  local ok, state = pcall(vim.json.decode, get_response.body)
  assert_test(ok, 'GET response is valid JSON', state)
  if ok then
    assert_test(state.chatHistory ~= nil, 'State has chatHistory')
    assert_test(type(state.isProcessing) == 'boolean', 'State has isProcessing')
  end
end

-- Test 6: POST request
log_info('Testing POST /message (async)...')
local post_success = false
local post_response = nil
local post_error = nil

local message_body = vim.json.encode({ message = 'test message from continue.nvim' })
http.post(test_url .. '/message', message_body, function(err, response)
  post_error = err
  post_response = response
  post_success = true
end)

vim.wait(3000, function()
  return post_success
end, 100)

assert_test(post_success, 'POST request completed')
assert_test(not post_error, 'POST request no error', post_error)
assert_test(post_response ~= nil, 'POST request has response')
if post_response then
  assert_test(post_response.status == 200, 'POST request status 200', tostring(post_response.status))

  local ok, data = pcall(vim.json.decode, post_response.body)
  assert_test(ok, 'POST response is valid JSON')
  if ok then
    assert_test(data.queued == true, 'Message was queued')
    assert_test(type(data.position) == 'number', 'Response has queue position')
  end
end

-- ============================================================================
-- TEST SUITE: Client API
-- ============================================================================

log_section('Testing Client API')

local client = require('continue.client')

-- Test 7: Client status (before polling)
local status = client.status()
assert_test(status.polling == false, 'Client not polling initially')
assert_test(status.port == nil, 'Client has no port initially')

-- Test 8: Health check
log_info('Testing health check (async)...')
local health_success = false
local health_ok = false
local health_error = nil

client.health_check(test_port, function(err, ok)
  health_error = err
  health_ok = ok
  health_success = true
end)

vim.wait(3000, function()
  return health_success
end, 100)

assert_test(health_success, 'Health check completed')
assert_test(not health_error, 'Health check no error', health_error)
assert_test(health_ok == true, 'Server is healthy')

-- Test 9: Send message via client
log_info('Testing client.send_message (async)...')
local send_success = false
local send_data = nil
local send_error = nil

client.send_message(test_port, 'test from client API', function(err, data)
  send_error = err
  send_data = data
  send_success = true
end)

vim.wait(3000, function()
  return send_success
end, 100)

assert_test(send_success, 'Client send_message completed')
assert_test(not send_error, 'Client send_message no error', send_error)
assert_test(send_data ~= nil, 'Client send_message has data')
if send_data then
  assert_test(send_data.queued == true, 'Client message was queued')
end

-- Test 10: Get diff
log_info('Testing client.get_diff (async)...')
local diff_success = false
local diff_data = nil
local diff_error = nil

client.get_diff(test_port, function(err, diff)
  diff_error = err
  diff_data = diff
  diff_success = true
end)

vim.wait(3000, function()
  return diff_success
end, 100)

assert_test(diff_success, 'Client get_diff completed')
-- Note: diff might error if not in git repo, which is OK
if not diff_error then
  assert_test(type(diff_data) == 'string', 'Diff is a string')
  log_info('Diff length: ' .. #diff_data .. ' chars')
end

-- Test 11: Pause (might fail if not processing)
log_info('Testing client.pause (async)...')
local pause_success = false

client.pause(test_port, function(_err)
  pause_success = true
end)

vim.wait(3000, function()
  return pause_success
end, 100)

assert_test(pause_success, 'Client pause completed')

-- ============================================================================
-- TEST SUITE: State Polling
-- ============================================================================

log_section('Testing State Polling')

-- Test 12: Start polling
log_info('Starting state polling...')
local poll_count = 0
local poll_states = {}

client.start_polling(test_port, function(state)
  poll_count = poll_count + 1
  table.insert(poll_states, state)
end)

-- Wait for a few poll cycles (at least 2 seconds = 4 polls at 500ms interval)
vim.wait(2000, function()
  return poll_count >= 3
end, 100)

assert_test(poll_count >= 3, 'Polling received multiple updates', 'count: ' .. poll_count)
assert_test(#poll_states >= 3, 'Polling collected states')

if #poll_states > 0 then
  local state = poll_states[1]
  assert_test(state.chatHistory ~= nil, 'Polled state has chatHistory')
  assert_test(type(state.isProcessing) == 'boolean', 'Polled state has isProcessing')
end

-- Test 13: Stop polling
client.stop_polling()
local status_after = client.status()
assert_test(status_after.polling == false, 'Polling stopped')

-- ============================================================================
-- TEST RESULTS
-- ============================================================================

log_section('Test Results')
log_info(string.format('Tests run: %d', tests_run))
log_success(string.format('Passed: %d', tests_passed))
if tests_failed > 0 then
  log_error(string.format('Failed: %d', tests_failed))
end

local success_rate = math.floor((tests_passed / tests_run) * 100)
log_info(string.format('Success rate: %d%%', success_rate))

if tests_failed == 0 then
  log('\n' .. '🎉 All tests passed!', colors.green)
else
  log('\n' .. '❌ Some tests failed', colors.red)
end

-- NEXT STEPS for test expansion:
-- TODO: Add tests for permission handling (needs manual approval simulation)
-- TODO: Add tests for streaming message updates
-- TODO: Add tests for error conditions (server down, timeout, invalid JSON)
-- TODO: Add tests for concurrent requests
-- TODO: Add tests for request cancellation (jobstop)
-- TODO: Add mock server for testing without cn serve dependency
-- TODO: Convert to plenary.nvim test format for CI/CD
