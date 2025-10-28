-- Process manager for cn serve

local M = {}

local state = {
	job_id = nil,
	port = nil,
	running = false,
	config = nil,
}

-- Check if cn is running on the given port
-- Useful if cn was started elsewhere
-- @param port number - Port to check
-- @return boolean - true if cn is running
local function check_if_cn_is_running(port)
	local http = require("continue.utils.http")
	return http.get(string.format("http://localhost:%d/state", port), function(err, _)
		if err then
			return false
		end
		return true
	end)
end

-- Find an available port in the configured range
-- @param start_port number - Start of port range
-- @param end_port number - End of port range
-- @return number|nil - Available port or nil if none found
local function find_available_port(start_port, end_port)
	for port = start_port, end_port do
		local server = vim.loop.new_tcp()
		local ok = pcall(function()
			server:bind("127.0.0.1", port)
		end)
		server:close()

		if ok then
			return port
		else
			check_if_cn_is_running(port)
			state.port = port
			state.running = true
		end
	end
	return nil
end

local function build_command(config)
	local cmd = {
		config.cn_bin or "cn",
		"serve",
		"--port",
		tostring(config.port),
		"--timeout",
		tostring(config.timeout or 300),
	}

	if config.continue_config then
		table.insert(cmd, "--config")
		table.insert(cmd, config.continue_config)
	end

	return cmd
end

-- Start cn serve process
-- @param config table - Configuration from init.lua
-- @param retry_count number - Internal retry counter (default 0)
-- @return boolean - Success or failure
function M.start(config, retry_count)
	retry_count = retry_count or 0
	local max_retries = config.max_port_retries or 10
	
	if retry_count >= max_retries then
		vim.notify("Failed to start cn serve after " .. max_retries .. " port attempts", vim.log.levels.ERROR)
		return false
	end

	if state.running then
		vim.notify("Continue server already running on port " .. state.port, vim.log.levels.WARN)
		return true
	end

	state.config = config

	-- Find available port
	local port = config.port
	if config.auto_find_port then
		local port_range = config.port_range or { 8000, 8010 }
		port = find_available_port(port_range[1], port_range[2])

		if not port and not state.running then
			vim.notify(
				string.format("No available ports in range %d-%d", port_range[1], port_range[2]),
				vim.log.levels.ERROR
			)
			return false
		end
		vim.notify(string.format("Using port %d", port), vim.log.levels.INFO)
	end

	-- Build command with current port
	local cmd = build_command(vim.tbl_extend("force", config, { port = port }))
	
	-- Start process
	state.job_id = vim.fn.jobstart(cmd, {
		on_stdout = function(_, data)
			for _, line in ipairs(data) do
				if line ~= "" then
					-- TODO: Add configurable logging level
					-- vim.notify('[cn serve] ' .. line, vim.log.levels.DEBUG)
				end
			end
		end,
		on_stderr = function(_, data)
			for _, line in ipairs(data) do
				if line ~= "" then
					-- Check for port collision
					if line:match("port.*in use") or line:match("EADDRINUSE") then
						vim.notify("Port " .. port .. " in use, trying port " .. (port + 1), vim.log.levels.WARN)
						-- Stop current attempt
						if state.job_id then
							vim.fn.jobstop(state.job_id)
						end
						state.running = false
						state.job_id = nil
						-- Retry with next port
						local new_config = vim.tbl_extend("force", config, { port = port + 1 })
						vim.defer_fn(function()
							M.start(new_config, retry_count + 1)
						end, 500)
					else
						vim.notify("[cn serve ERROR] " .. line, vim.log.levels.ERROR)
					end
				end
			end
		end,
		on_exit = function(_, code)
			state.running = false
			state.job_id = nil
			if code ~= 0 then
				vim.notify("cn serve exited with code " .. code, vim.log.levels.ERROR)
			end
		end,
	})

	if state.job_id <= 0 then
		vim.notify("Failed to start cn serve", vim.log.levels.ERROR)
		return false
	end

	state.port = port
	state.running = true

	-- Wait for server to be ready
	M.wait_for_ready(5000, function(err)
		if err then
			vim.notify("cn serve failed to start: " .. err, vim.log.levels.ERROR)
			M.stop()
		else
			vim.notify("Continue server ready on port " .. port, vim.log.levels.INFO)
			-- Start polling if auto_start is enabled
			if config.auto_start then
				require("continue.client").start_polling(port)
			end
		end
	end)

	return true
end

-- Wait for server to respond to health check
-- @param timeout_ms number - Timeout in milliseconds
-- @param callback function(err) - Called when ready or timeout
function M.wait_for_ready(timeout_ms, callback)
	local start = vim.loop.now()
	local timer = vim.loop.new_timer()
	local http = require("continue.utils.http")

	timer:start(
		100,
		100,
		vim.schedule_wrap(function()
			if not state.running then
				timer:stop()
				timer:close()
				callback("Server not running")
				return
			end

			http.get(string.format("http://localhost:%d/state", state.port), function(err, _)
				if not err then
					-- Server is ready
					timer:stop()
					timer:close()
					callback(nil)
				elseif vim.loop.now() - start > timeout_ms then
					-- Timeout
					timer:stop()
					timer:close()
					callback("Timeout waiting for server to start")
				end
				-- Otherwise keep polling
			end)
		end)
	)
end

-- Stop cn serve gracefully
function M.stop()
	if not state.running then
		return
	end

	local http = require("continue.utils.http")

	-- Try graceful shutdown via POST /exit
	http.post(string.format("http://localhost:%d/exit", state.port), "{}", function(err)
		if err then
			vim.notify("Graceful shutdown failed, forcing...", vim.log.levels.WARN)
		end

		-- Force kill after 2 seconds if still running
		vim.defer_fn(function()
			if state.job_id then
				vim.fn.jobstop(state.job_id)
				state.job_id = nil
				state.running = false
			end
		end, 2000)
	end)
end

-- Get current process status
-- @return table - Status information
function M.status()
	return {
		running = state.running,
		port = state.port,
		job_id = state.job_id,
	}
end

-- TODO: Add health check endpoint polling
-- TODO: Add auto-restart on crash (if configured)
-- TODO: Add process output logging to file
-- TODO: Handle multiple retries for port selection

return M