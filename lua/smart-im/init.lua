local M = {}

function M.setup(opts)
	require("smart-im.config").setup(opts)
end

function M.get_current_im()
	return require("smart-im.im").get_current()
end

function M.set_im(im)
	return require("smart-im.im").set(im)
end

function M.remember_im(ft)
	require("smart-im.im").remember(ft)
end

function M.restore_im(ft)
	require("smart-im.im").restore(ft)
end

function M.switch_to_default()
	require("smart-im.im").switch_to_default()
end

function M.clear_memory(ft)
	require("smart-im.state").clear(ft)
end

function M.get_state()
	return require("smart-im.state").get()
end

function M.set(ft, im)
	require("smart-im.state").set(ft, im)
end

return M
