local M = {}

function M.setup()
	local im = require("smart-im.im")
	local group = vim.api.nvim_create_augroup("SmartIM", { clear = true })

	vim.api.nvim_create_autocmd("InsertLeave", {
		group = group,
		callback = function()
			im.remember()
			im.switch_to_default()
		end,
	})

	vim.api.nvim_create_autocmd("InsertEnter", {
		group = group,
		callback = function()
			im.restore()
		end,
	})

	vim.api.nvim_create_autocmd("BufLeave", {
		group = group,
		callback = function()
			if vim.fn.mode():match("^[iR]") then
				im.remember()
			end
		end,
	})
end

return M
