local M = {}

---@class SmartIMConfig
---@field default_im string Default input method identifier
---@field restore_previous boolean Whether to restore previous IM on insert enter
---@field switch_on_leave boolean Whether to switch to default IM on insert leave
---@field save_im_for_filetypes string[] List of filetypes to track separately
---@field get_im_cmd? string Command to get current input method
---@field set_im_cmd? string Command to set input method (use %s for IM placeholder)
---@field restore_events string[] Events that trigger IM restoration
---@field remember_events string[] Events that trigger IM remembering
---@field debug boolean Enable debug logging

---@type SmartIMConfig
M.defaults = {
	default_im = "com.apple.keylayout.ABC",
	restore_previous = true,
	switch_on_leave = true,
	save_im_for_filetypes = {},
	get_im_cmd = nil,
	set_im_cmd = nil,
	restore_events = { "InsertEnter" },
	remember_events = { "InsertLeave", "CmdlineLeave" },
	debug = false,
}

---@type SmartIMConfig
M.options = vim.deepcopy(M.defaults)

---@param opts? SmartIMConfig User configuration options
---@param opts? SmartIMConfig User configuration options
function M.setup(opts)
	opts = opts or {}

	-- Validate user input
	if opts.save_im_for_filetypes ~= nil and type(opts.save_im_for_filetypes) ~= "table" then
		vim.notify("smart-im: save_im_for_filetypes must be a table", vim.log.levels.ERROR)
		opts.save_im_for_filetypes = nil
	end

	if opts.restore_events ~= nil and type(opts.restore_events) ~= "table" then
		vim.notify("smart-im: restore_events must be a table", vim.log.levels.ERROR)
		opts.restore_events = nil
	end

	if opts.remember_events ~= nil and type(opts.remember_events) ~= "table" then
		vim.notify("smart-im: remember_events must be a table", vim.log.levels.ERROR)
		opts.remember_events = nil
	end

	local utils = require("smart-im.utils")
	local os_cmds = utils.detect_commands()

	-- First: merge defaults with user options
	M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts)

	-- Second: apply auto-detected commands only if user didn't provide them
	if os_cmds then
		M.options.get_im_cmd = M.options.get_im_cmd or os_cmds.get
		M.options.set_im_cmd = M.options.set_im_cmd or os_cmds.set
	end

	if not M.options.get_im_cmd or not M.options.set_im_cmd then
		vim.notify(
			"smart-im.nvim: Could not detect input method commands. Please set get_im_cmd and set_im_cmd manually.",
			vim.log.levels.WARN
		)
		return
	end

	local setup = require("smart-im.setup")
	setup.autocmds()
	setup.commands()
end

return M
