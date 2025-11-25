local M = {}

function M.autocmds()
	local im = require("smart-im.im")
	local utils = require("smart-im.utils")
	local group = vim.api.nvim_create_augroup("SmartIM", { clear = true })
	local last_insert_buf = nil

	vim.api.nvim_create_autocmd("InsertEnter", {
		group = group,
		callback = function(args)
			last_insert_buf = args.buf
		end,
	})

	-- Track insert mode transitions (normal buffers and terminals)
	vim.api.nvim_create_autocmd("ModeChanged", {
		group = group,
		pattern = "i:n",
		callback = function(args)
			local buftype = vim.bo[args.buf].buftype
			utils.debug_log(
				"ModeChanged i:n buftype="
					.. buftype
					.. " buf="
					.. args.buf
					.. " last_insert_buf="
					.. tostring(last_insert_buf)
			)
			if last_insert_buf and vim.api.nvim_buf_is_valid(last_insert_buf) and last_insert_buf == args.buf then
				im.remember(args.buf)
			end
			im.switch_to_default()
		end,
	})

	vim.api.nvim_create_autocmd("ModeChanged", {
		group = group,
		pattern = "n:i",
		callback = function(args)
			local buftype = vim.bo[args.buf].buftype
			utils.debug_log("ModeChanged n:i buftype=" .. buftype .. " buf=" .. args.buf)
			im.restore(args.buf)
		end,
	})

	-- Track terminal mode transitions
	vim.api.nvim_create_autocmd("ModeChanged", {
		group = group,
		pattern = "t:nt",
		callback = function(args)
			local buftype = vim.bo[args.buf].buftype
			utils.debug_log("ModeChanged t:nt buftype=" .. buftype .. " buf=" .. args.buf)
			im.remember(args.buf)
			im.switch_to_default()
		end,
	})

	vim.api.nvim_create_autocmd("ModeChanged", {
		group = group,
		pattern = "nt:t",
		callback = function(args)
			local buftype = vim.bo[args.buf].buftype
			utils.debug_log("ModeChanged nt:t buftype=" .. buftype .. " buf=" .. args.buf)
			im.restore(args.buf)
		end,
	})

	vim.api.nvim_create_autocmd("WinLeave", {
		group = group,
		callback = function(args)
			local buftype = vim.bo[args.buf].buftype
			if buftype ~= "terminal" then
				return
			end
			utils.debug_log("WinLeave buftype=" .. buftype .. " buf=" .. args.buf)
			im.remember(args.buf)
		end,
	})

	vim.api.nvim_create_autocmd("ModeChanged", {
		group = group,
		pattern = "t:n",
		callback = function(args)
			local buftype = vim.bo[args.buf].buftype
			if buftype == "prompt" then
				return
			end
			utils.debug_log("ModeChanged t:n buftype=" .. buftype .. " buf=" .. args.buf)
			im.switch_to_default()
		end,
	})

	-- Cleanup buffer data when buffer is deleted
	vim.api.nvim_create_autocmd("BufDelete", {
		group = group,
		callback = function(args)
			im.cleanup(args.buf)
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
