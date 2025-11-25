local M = {}

-- Minimum Neovim version required
local MIN_NVIM = "0.9.0"

---@class SmartIMConfig
---@field default_im string Default input method identifier (used in normal mode)
---@field get_im_cmd? string Command to get current input method
---@field set_im_cmd? string Command to set input method (use %s for IM placeholder)
---@field debug boolean Enable debug logging

---@type SmartIMConfig
M.defaults = {
	default_im = "com.apple.keylayout.US",
	get_im_cmd = nil,
	set_im_cmd = nil,
	debug = false,
}

---@type SmartIMConfig
M.options = vim.deepcopy(M.defaults)
M.is_configured = false

---@param opts? SmartIMConfig User configuration options
function M.setup(opts)
	opts = opts or {}

	if not vim.fn.has("nvim-" .. MIN_NVIM) then
		vim.notify(string.format("smart-im.nvim requires Neovim %s or newer", MIN_NVIM), vim.log.levels.ERROR)
		return
	end

	-- Validate user input
	if opts.default_im ~= nil and type(opts.default_im) ~= "string" then
		vim.notify("smart-im: default_im must be a string", vim.log.levels.ERROR)
		opts.default_im = nil
	end

	if opts.get_im_cmd ~= nil and type(opts.get_im_cmd) ~= "string" then
		vim.notify("smart-im: get_im_cmd must be a string", vim.log.levels.ERROR)
		opts.get_im_cmd = nil
	end

	if opts.set_im_cmd ~= nil and type(opts.set_im_cmd) ~= "string" then
		vim.notify("smart-im: set_im_cmd must be a string", vim.log.levels.ERROR)
		opts.set_im_cmd = nil
	end

	local utils = require("smart-im.utils")
	local os_cmds = utils.detect_commands()

	-- First: merge defaults with user options
	M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts)
	M.is_configured = false

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
	M.is_configured = true
end

return M
