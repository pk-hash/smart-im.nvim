local M = {}

M.defaults = {
	default_im = "com.apple.keylayout.ABC",
	restore_previous = true,
	switch_on_leave = true,
	save_im_for_filetypes = {},
	get_im_cmd = nil,
	set_im_cmd = nil,
}

M.options = {}

function M.setup(opts)
	opts = opts or {}

	local utils = require("smart-im.utils")
	local os_cmds = utils.detect_commands()
	if os_cmds then
		M.options.get_im_cmd = opts.get_im_cmd or os_cmds.get
		M.options.set_im_cmd = opts.set_im_cmd or os_cmds.set
	end

	M.options = vim.tbl_deep_extend("force", M.defaults, opts)

	if not M.options.get_im_cmd or not M.options.set_im_cmd then
		vim.notify(
			"smart-im.nvim: Could not detect input method commands. Please set get_im_cmd and set_im_cmd manually.",
			vim.log.levels.WARN
		)
		return
	end

	require("smart-im.autocmds").setup()
	require("smart-im.commands").setup()
end

return M
