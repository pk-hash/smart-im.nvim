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

-- Detect OS and set appropriate commands
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

-- Execute command and return trimmed output
function M.execute(cmd)
	local handle = io.popen(cmd .. " 2>/dev/null")
	if not handle then
		return nil
	end

	local result = handle:read("*a")
	handle:close()

	if result then
		return vim.trim(result)
	end
	return nil
end

return M
