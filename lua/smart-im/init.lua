local config = require("smart-im.config")
local state = require("smart-im.state")
local utils = require("smart-im.utils")

local M = {}

M.config = vim.deepcopy(config.defaults)

local function get_filetype()
	return vim.bo.filetype or ""
end

local function should_track_filetype(ft)
	if not ft or ft == "" then
		return false
	end

	local save_for = M.config.save_im_for_filetypes
	if not save_for or vim.tbl_isempty(save_for) then
		return true
	end

	return vim.tbl_contains(save_for, ft)
end

function M.get_current_im()
	local cmd = M.config.get_im_cmd
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

function M.set_im(im)
	if not im or im == "" then
		return false
	end

	local cmd = M.config.set_im_cmd
	if not cmd then
		return false
	end

	local set_cmd = string.format(cmd, im)
	utils.execute(set_cmd)
	state.current_im = im
	return true
end

function M.remember_im(ft)
	ft = ft or get_filetype()

	if not should_track_filetype(ft) then
		return
	end

	local im = M.get_current_im()
	if im then
		state.per_filetype[ft] = im
	end
end

function M.restore_im(ft)
	if not M.config.restore_previous then
		return
	end

	ft = ft or get_filetype()
	local im = nil

	if should_track_filetype(ft) then
		im = state.per_filetype[ft]
	end

	im = im or M.config.default_im

	if im then
		M.set_im(im)
	end
end

function M.switch_to_default()
	if M.config.switch_on_leave and M.config.default_im then
		M.set_im(M.config.default_im)
	end
end

function M.clear_memory(ft)
	if ft then
		state.per_filetype[ft] = nil
	else
		state.per_filetype = {}
	end
end

function M.get_state()
	return vim.deepcopy(state.per_filetype)
end

function M.set(ft, im)
	if ft and im then
		state.per_filetype[ft] = im
	end
end

local function setup_autocmds()
	local group = vim.api.nvim_create_augroup("SmartIM", { clear = true })

	vim.api.nvim_create_autocmd("InsertLeave", {
		group = group,
		callback = function()
			M.remember_im()
			M.switch_to_default()
		end,
	})

	vim.api.nvim_create_autocmd("InsertEnter", {
		group = group,
		callback = function()
			M.restore_im()
		end,
	})

	vim.api.nvim_create_autocmd("BufLeave", {
		group = group,
		callback = function()
			if vim.fn.mode():match("^[iR]") then
				M.remember_im()
			end
		end,
	})
end

local function setup_commands()
	vim.api.nvim_create_user_command("SmartIMClear", function(args)
		M.clear_memory(args.args ~= "" and args.args or nil)
		vim.notify("smart-im.nvim: Memory cleared", vim.log.levels.INFO)
	end, {
		nargs = "?",
		desc = "Clear input method memory (optionally for specific filetype)",
	})

	vim.api.nvim_create_user_command("SmartIMStatus", function()
		local status = M.get_state()
		local lines = { "smart-im.nvim status:" }
		for ft, im in pairs(status) do
			table.insert(lines, string.format("  %s: %s", ft, im))
		end
		if vim.tbl_isempty(status) then
			table.insert(lines, "  (no remembered input methods)")
		end
		vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
	end, {
		desc = "Show remembered input methods per filetype",
	})
end

function M.setup(opts)
	opts = opts or {}

	local os_cmds = utils.detect_commands()
	if os_cmds then
		M.config.get_im_cmd = opts.get_im_cmd or os_cmds.get
		M.config.set_im_cmd = opts.set_im_cmd or os_cmds.set
	end

	M.config = vim.tbl_deep_extend("force", M.config, opts)

	if not M.config.get_im_cmd or not M.config.set_im_cmd then
		vim.notify(
			"smart-im.nvim: Could not detect input method commands. Please set get_im_cmd and set_im_cmd manually.",
			vim.log.levels.WARN
		)
		return
	end

	setup_autocmds()
	setup_commands()
end

return M
