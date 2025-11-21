local M = {}

function M.setup()
	local state = require("smart-im.state")

	vim.api.nvim_create_user_command("SmartIMClear", function(args)
		state.clear(args.args ~= "" and args.args or nil)
		vim.notify("smart-im.nvim: Memory cleared", vim.log.levels.INFO)
	end, {
		nargs = "?",
		desc = "Clear input method memory (optionally for specific filetype)",
	})

	vim.api.nvim_create_user_command("SmartIMStatus", function()
		local status = state.get()
		local lines = { "smart-im.nvim status:" }
		for ft, im in pairs(status) do
			table.insert(lines, string.format("  %s: %s", ft, im))
		end
		if vim.tbl_isempty(status) then
			table.insert(lines, "  (no remembered input methods)")
		end
		vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
	end, {
		desc = "Show remembered input methods per filetype",
	})
end

return M
