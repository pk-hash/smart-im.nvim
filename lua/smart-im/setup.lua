local M = {}

function M.autocmds()
	local autocmds = require("smart-im.autocmds")
	local group = vim.api.nvim_create_augroup("SmartIM", { clear = true })

	vim.api.nvim_create_autocmd("InsertEnter", {
		group = group,
		callback = autocmds.on_insert_enter,
	})

	vim.api.nvim_create_autocmd("ModeChanged", {
		group = group,
		pattern = "i:n",
		callback = autocmds.on_insert_leave,
	})

	vim.api.nvim_create_autocmd("ModeChanged", {
		group = group,
		pattern = "n:i",
		callback = autocmds.on_insert_enter_restore,
	})

	vim.api.nvim_create_autocmd("ModeChanged", {
		group = group,
		pattern = "t:nt",
		callback = autocmds.on_terminal_leave,
	})

	vim.api.nvim_create_autocmd("ModeChanged", {
		group = group,
		pattern = "nt:t",
		callback = autocmds.on_terminal_enter,
	})

	vim.api.nvim_create_autocmd("WinLeave", {
		group = group,
		callback = autocmds.on_win_leave,
	})

	vim.api.nvim_create_autocmd("BufDelete", {
		group = group,
		callback = autocmds.on_buf_delete,
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

		for bufnr, im in pairs(status.per_buffer) do
			if vim.api.nvim_buf_is_valid(bufnr) then
				local name = vim.api.nvim_buf_get_name(bufnr)
				local ft = vim.bo[bufnr].filetype or ""
				if name == "" then
					name = "[No Name]"
				end
				table.insert(lines, string.format("  #%d (%s) %s: %s", bufnr, ft, name, im))
			end
			has_data = true
		end

		if not has_data then
			table.insert(lines, "  (no remembered input methods per buffer)")
		end

		vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
	end, {
		desc = "Show remembered input methods per buffer",
	})
end

return M
