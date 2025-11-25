local M = {}

local last_insert_buf = nil

---@param args table
function M.on_insert_enter(args)
	last_insert_buf = args.buf
end

---@param args table
function M.on_insert_leave(args)
	local im = require("smart-im.im")
	if last_insert_buf and vim.api.nvim_buf_is_valid(last_insert_buf) and last_insert_buf == args.buf then
		im.remember(args.buf)
	end
	im.switch_to_default()
end

---@param args table
function M.on_insert_enter_restore(args)
	local im = require("smart-im.im")
	im.restore(args.buf)
end

---@param args table
function M.on_terminal_leave(args)
	local im = require("smart-im.im")
	im.remember(args.buf)
	im.switch_to_default()
end

---@param args table
function M.on_terminal_enter(args)
	local im = require("smart-im.im")
	im.restore(args.buf)
end

---@param args table
function M.on_terminal_to_normal(args)
	local buftype = vim.bo[args.buf].buftype
	if buftype == "prompt" then
		return
	end
	local im = require("smart-im.im")
	im.switch_to_default()
end

---@param args table
function M.on_win_leave(args)
	local buftype = vim.bo[args.buf].buftype
	if buftype ~= "terminal" then
		return
	end
	local im = require("smart-im.im")
	im.remember(args.buf)
end

---@param args table
function M.on_buf_delete(args)
	local im = require("smart-im.im")
	im.cleanup(args.buf)
end

return M
