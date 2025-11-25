local M = {}

local config = require("smart-im.config")
local im = require("smart-im.im")
local state = require("smart-im.state")

function M.setup(opts)
	config.setup(opts)
end

function M.get_current_im()
	return im.get_current()
end

function M.set_im(im_name)
	return im.set(im_name)
end

function M.remember_im(bufnr)
	im.remember(bufnr)
end

function M.restore_im(bufnr)
	im.restore(bufnr)
end

function M.switch_to_default()
	im.switch_to_default()
end

function M.clear_memory(bufnr)
	state.clear(bufnr)
end

function M.get_state()
	return state.get()
end

function M.set(bufnr, im_name)
	state.set(bufnr, im_name)
end

return M
