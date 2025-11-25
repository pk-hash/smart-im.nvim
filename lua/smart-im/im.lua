local state = require("smart-im.state")
local utils = require("smart-im.utils")
local config = require("smart-im.config")

local M = {}

local function log_debug(msg)
	if config.options.debug then
		vim.notify("smart-im: " .. msg, vim.log.levels.DEBUG)
	end
end

---@return integer|nil
local function get_bufnr(bufnr)
	if bufnr and bufnr ~= 0 then
		return bufnr
	end
	return vim.api.nvim_get_current_buf()
end

---@param bufnr integer
---@return boolean
local function should_exclude_buffer(bufnr)
	if not bufnr or bufnr == 0 or not vim.api.nvim_buf_is_valid(bufnr) then
		return true
	end

	-- Check if buffer is a special buffer type (prompt, etc.) but allow terminal
	local buftype = vim.api.nvim_get_option_value("buftype", { buf = bufnr })
	if buftype ~= "" and buftype ~= "terminal" then
		return true
	end

	-- Exclude floating windows
	local wins = vim.fn.win_findbuf(bufnr)
	for _, win in ipairs(wins) do
		local win_config = vim.api.nvim_win_get_config(win)
		if win_config.relative ~= "" then
			return true
		end
	end

	return false
end

---Get current input method from system
---@return string? im Current input method identifier, or nil on failure
function M.get_current_im()
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
		log_debug("cannot set empty IM")
		return false
	end

	local cmd = config.options.set_im_cmd
	if not cmd or cmd == "" then
		log_debug("set_im_cmd not configured")
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

---Remember input method for the given buffer
---@param bufnr? integer Buffer to remember for (defaults to current buffer)
function M.remember(bufnr)
	bufnr = get_bufnr(bufnr)
	if should_exclude_buffer(bufnr) then
		log_debug(string.format("skipping remember for excluded buffer #%d", bufnr))
		return
	end

	-- Get current IM from the system
	local im = M.get_current_im()
	if not im then
		log_debug("no IM to remember")
		return
	end

	-- Don't store if it's the default IM
	if im == config.options.default_im then
		-- Clear any previously stored IM for this buffer
		if state.per_buffer[bufnr] then
			state.per_buffer[bufnr] = nil
			log_debug(string.format("cleared default IM for buffer #%d", bufnr))
		end
		return
	end

	local old_im = state.per_buffer[bufnr]
	state.per_buffer[bufnr] = im
	log_debug(string.format("remembered IM '%s' for buffer #%d (was: %s)", im, bufnr, old_im or "nil"))
end

---Restore input method for the given buffer
---@param bufnr? integer Buffer to restore for (defaults to current buffer)
---@return string? im The IM that was restored, or nil if nothing was restored
function M.restore(bufnr)
	bufnr = get_bufnr(bufnr)

	local im = nil
	if not should_exclude_buffer(bufnr) then
		im = state.per_buffer[bufnr]
	end

	-- Restore saved IM or default
	local target_im = im or config.options.default_im
	if target_im then
		log_debug(string.format("restoring IM '%s' for buffer #%d", target_im, bufnr or -1))
		M.set(target_im)
		return target_im
	end

	return nil
end

---Switch to default input method
function M.switch_to_default()
	if config.options.default_im then
		M.set(config.options.default_im)
	end
end

---Cleanup buffer data
---@param bufnr integer Buffer number to cleanup
function M.cleanup(bufnr)
	if state.per_buffer[bufnr] then
		state.per_buffer[bufnr] = nil
		log_debug(string.format("cleaned up buffer #%d", bufnr))
	end
end

return M
