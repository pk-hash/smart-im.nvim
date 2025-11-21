local state = require("smart-im.state")
local utils = require("smart-im.utils")
local config = require("smart-im.config")

local M = {}

local function get_filetype()
	return vim.bo.filetype or ""
end

local function should_track_filetype(ft)
	if not ft or ft == "" then
		return false
	end

	local save_for = config.options.save_im_for_filetypes
	if not save_for or vim.tbl_isempty(save_for) then
		return true
	end

	return vim.tbl_contains(save_for, ft)
end

function M.get_current()
	local cmd = config.options.get_im_cmd
	if not cmd then
		return nil
	end

	local im = utils.execute(cmd)
	if im and im ~= "" then
		state.current_im = im
		return im
	end
	return nil
end

function M.set(im)
	if not im or im == "" then
		return false
	end

	local cmd = config.options.set_im_cmd
	if not cmd then
		return false
	end

	local set_cmd = string.format(cmd, im)
	utils.execute(set_cmd)
	state.current_im = im
	return true
end

function M.remember(ft)
	ft = ft or get_filetype()

	if not should_track_filetype(ft) then
		return
	end

	local im = M.get_current()
	if im then
		state.per_filetype[ft] = im
	end
end

function M.restore(ft)
	if not config.options.restore_previous then
		return
	end

	ft = ft or get_filetype()
	local im = nil

	if should_track_filetype(ft) then
		im = state.per_filetype[ft]
	end

	im = im or config.options.default_im

	if im then
		M.set(im)
	end
end

function M.switch_to_default()
	if config.options.switch_on_leave and config.options.default_im then
		M.set(config.options.default_im)
	end
end

return M
