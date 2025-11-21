local M = {}

local OS_COMMANDS = {
	Darwin = {
		{ "im-select" },
		{ "macism" },
	},
	Linux = {
		{ "ibus", args = { get = "engine", set = "engine %s" } },
		{ "fcitx-remote", args = { get = "-n", set = "-s %s" } },
		{ "fcitx5-remote", args = { get = "-n", set = "-s %s" } },
	},
	Windows = {
		{ "im-select.exe" },
	},
}

---Detect appropriate input method commands for current OS
---@return {get: string, set: string}? commands Table with get/set commands, or nil if not detected
function M.detect_commands()
	local uname = vim.loop.os_uname().sysname

	-- Normalize OS name
	local os_key
	if uname == "Darwin" then
		os_key = "Darwin"
	elseif uname == "Linux" then
		os_key = "Linux"
	elseif uname:match("Windows") or uname:match("MINGW") or uname:match("MSYS") then
		os_key = "Windows"
	else
		return nil
	end

	local commands = OS_COMMANDS[os_key]
	if not commands then
		return nil
	end

	-- Find first available command
	for _, entry in ipairs(commands) do
		local cmd = entry[1]
		if vim.fn.executable(cmd) == 1 then
			local args = entry.args
			if args then
				-- Linux-style with different get/set syntax
				return {
					get = cmd .. " " .. args.get,
					set = cmd .. " " .. args.set,
				}
			else
				-- Simple style (macOS/Windows): command accepts argument directly
				return {
					get = cmd,
					set = cmd .. " %s",
				}
			end
		end
	end

	return nil
end

---Execute shell command and return output
---@param cmd string Command to execute
---@return string? result Command output (trimmed), or nil on failure
---@return boolean success True if command executed successfully
function M.execute(cmd)
	local config = require("smart-im.config")
	local stderr_redirect = config.options.debug and " 2>&1" or " 2>/dev/null"

	local handle = io.popen(cmd .. stderr_redirect)
	if not handle then
		if config.options.debug then
			vim.notify("smart-im: Failed to execute: " .. cmd, vim.log.levels.ERROR)
		end
		return nil, false
	end

	local result = handle:read("*a")
	local ok, _, code = handle:close()
	local success = false
	if ok == true then
		success = true
	elseif code and code == 0 then
		success = true
	end

	if not success and config.options.debug then
		vim.notify("smart-im: Command failed: " .. cmd, vim.log.levels.WARN)
	end

	if result then
		result = vim.trim(result)
	end

	return result, success
end

return M
