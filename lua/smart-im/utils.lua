local M = {}

local OS_COMMANDS = {
	Darwin = {
		{ cmd = "im-select", get = "im-select", set = "im-select %s" },
		{ cmd = "macism", get = "macism", set = "macism %s" },
	},
	Linux = {
		{ cmd = "ibus", get = "ibus engine", set = "ibus engine %s" },
		{ cmd = "fcitx-remote", get = "fcitx-remote -n", set = "fcitx-remote -s %s" },
		{ cmd = "fcitx5-remote", get = "fcitx5-remote -n", set = "fcitx5-remote -s %s" },
	},
	Windows = {
		{ cmd = "im-select.exe", get = "im-select.exe", set = "im-select.exe %s" },
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
		if vim.fn.executable(entry.cmd) == 1 then
			return {
				get = entry.get,
				set = entry.set,
			}
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
