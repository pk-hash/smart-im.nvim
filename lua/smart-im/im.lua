local state = require("smart-im.state")
local utils = require("smart-im.utils")
local config = require("smart-im.config")

local M = {}

local function log_debug(msg)
	if config.options.debug then
		vim.notify("smart-im: " .. msg, vim.log.levels.DEBUG)
	end
end

---@return string
local function get_filetype()
	return vim.bo.filetype or ""
end

---@param ft string
---@return boolean
local function should_track_filetype(ft)
	if not ft or ft == "" then
		return false
	end

	local save_for = config.options.remember_filetypes

	-- Shouldn't happen (always set by config), but be defensive
	if not save_for then
		return false
	end

	-- Check if filetype is in the list
	return vim.tbl_contains(save_for, ft)
end

---Get current input method from system
---@return string? im Current input method identifier, or nil on failure
function M.get_current()
	local cmd = config.options.get_im_cmd
	if not cmd then
		return nil
	end

	local im, ok = utils.execute(cmd)
	if ok and im and im ~= "" then
		state.current_im = im
		return im
	end
	return nil
end

---Set input method
---@param im string Input method identifier to set
---@return boolean success True if IM was set successfully
function M.set(im)
	if not im or im == "" then
		return false
	end

	local cmd = config.options.set_im_cmd
	if not cmd then
		return false
	end

	local set_cmd = string.format(cmd, im)
	local _, ok = utils.execute(set_cmd)
	if not ok then
		log_debug(string.format("failed to set IM to '%s' using command '%s'", im, set_cmd))
		return false
	end

	state.current_im = im
	log_debug(string.format("set IM to '%s'", im))
	return true
end

---Remember current input method for the given filetype
---@param ft? string Filetype to remember for (defaults to current buffer filetype)
function M.remember(ft)
	ft = ft or get_filetype()

	local im = M.get_current()
	if not im then
		return
	end

	if should_track_filetype(ft) then
		-- Track per-filetype
		state.per_filetype[ft] = im
		log_debug(string.format("remembered IM '%s' for filetype '%s'", im, ft))
	else
		-- Track globally for all untracked filetypes
		state.global = im
		log_debug(string.format("remembered IM '%s' for global/untracked filetypes", im))
	end
end

---Restore input method for the given filetype
---@param ft? string Filetype to restore for (defaults to current buffer filetype)
function M.restore(ft)
	if not config.options.restore_previous then
		return
	end

	ft = ft or get_filetype()
	local im = nil

	if should_track_filetype(ft) then
		-- Try to restore per-filetype state
		im = state.per_filetype[ft]
	else
		-- Use global state for untracked filetypes
		im = state.global
	end

	-- Fallback to default if no state exists
	im = im or config.options.default_im

	if im then
		log_debug(string.format("restoring IM '%s' for filetype '%s'", im, ft or ""))
		M.set(im)
	end
end

---Switch to default input method if configured to do so
function M.switch_to_default()
	if config.options.switch_on_leave and config.options.default_im then
		M.set(config.options.default_im)
	end
end

return M
