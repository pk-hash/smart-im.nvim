local M = {}

function M.autocmds()
	local im = require("smart-im.im")
	local config = require("smart-im.config")
	local group = vim.api.nvim_create_augroup("SmartIM", { clear = true })

	-- Create autocmds for remembering IM
	for _, event in ipairs(config.options.remember_events) do
		vim.api.nvim_create_autocmd(event, {
			group = group,
			callback = function()
				im.remember()
				im.switch_to_default()
			end,
		})
	end

	-- Create autocmds for restoring IM
	for _, event in ipairs(config.options.restore_events) do
		vim.api.nvim_create_autocmd(event, {
			group = group,
			callback = function()
				im.restore()
			end,
		})
	end

	-- Always remember on BufLeave if in insert/replace mode
	vim.api.nvim_create_autocmd("BufLeave", {
		group = group,
		callback = function()
			if vim.fn.mode():match("^[iR]") then
				im.remember()
			end
		end,
	})
end

function M.commands()
	local state = require("smart-im.state")

	vim.api.nvim_create_user_command("SmartIMClear", function()
		state.clear()
		vim.notify("smart-im.nvim: Memory cleared", vim.log.levels.INFO)
	end, {
		nargs = 0,
		desc = "Clear all remembered input methods",
	})

	vim.api.nvim_create_user_command("SmartIMStatus", function()
		local status = state.get()
		local lines = { "smart-im.nvim status:" }
		local has_data = false

		-- Per-filetype
		for ft, im in pairs(status.per_filetype) do
			table.insert(lines, string.format("  %s: %s", ft, im))
			has_data = true
		end

		-- Global
		if status.global then
			table.insert(lines, string.format("  (global): %s", status.global))
			has_data = true
		end

		if not has_data then
			table.insert(lines, "  (no remembered input methods)")
		end

		vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
	end, {
		desc = "Show remembered input methods per filetype",
	})
end

return M
