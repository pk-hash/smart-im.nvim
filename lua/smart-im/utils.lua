local M = {}

-- Detect OS and set appropriate commands
function M.detect_commands()
	local uname = vim.loop.os_uname().sysname

	if uname == "Darwin" then
		return {
			get = "im-select",
			set = "im-select %s",
		}
	elseif uname == "Linux" then
		if vim.fn.executable("ibus") == 1 then
			return {
				get = "ibus engine",
				set = "ibus engine %s",
			}
		elseif vim.fn.executable("fcitx-remote") == 1 then
			return {
				get = "fcitx-remote -n",
				set = "fcitx-remote -s %s",
			}
		elseif vim.fn.executable("fcitx5-remote") == 1 then
			return {
				get = "fcitx5-remote -n",
				set = "fcitx5-remote -s %s",
			}
		end
	elseif uname:match("Windows") then
		return {
			get = "im-select.exe",
			set = "im-select.exe %s",
		}
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
