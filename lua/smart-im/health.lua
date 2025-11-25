local config = require("smart-im.config")
local utils = require("smart-im.utils")

local M = {}

local function check_command(health, label, cmd)
	if not cmd or cmd == "" then
		health.error(string.format("%s command is not configured", label))
		return
	end

	local bin = cmd:match("^%S+")
	if bin and vim.fn.executable(bin) == 1 then
		health.ok(string.format("%s command available: %s", label, cmd))
	else
		health.error(string.format("%s command not found or not executable: %s", label, cmd))
	end
end

local function get_health_reporters()
	local ok, health_mod = pcall(function()
		if vim.health then
			return vim.health
		end
		return require("vim.health")
	end)
	if not ok or not health_mod then
		return nil
	end

	if not (health_mod.start or health_mod.report_start) then
		return nil
	end

	return {
		start = health_mod.start or health_mod.report_start,
		ok = health_mod.ok or health_mod.report_ok,
		warn = health_mod.warn or health_mod.report_warn,
		error = health_mod.error or health_mod.report_error,
	}
end

function M.check()
	local health = get_health_reporters()
	if not health then
		vim.notify("smart-im: Health API not available (requires Neovim 0.9+)", vim.log.levels.ERROR)
		return
	end

	health.start("smart-im.nvim")

	local options = config.options
	if not config.is_configured then
		options = vim.deepcopy(config.defaults)
		health.warn(
			"smart-im: setup() has not been called; reporting using default configuration. Call require('smart-im').setup({...}) to apply your settings."
		)
	end

	-- Default input method
	if options.default_im and options.default_im ~= "" then
		health.ok(string.format("default_im set to '%s'", options.default_im))
	else
		health.warn("default_im is not set; restore behavior falls back to system defaults")
	end

	-- IM commands
	if not options.get_im_cmd or not options.set_im_cmd then
		local detected = utils.detect_commands()
		if detected then
			health.warn(
				string.format(
					"Commands not configured; would auto-detect get='%s', set='%s'",
					detected.get,
					detected.set
				)
			)
		else
			health.error("Input method commands not configured and could not auto-detect for this OS")
		end
	else
		check_command(health, "get_im_cmd", options.get_im_cmd)
		check_command(health, "set_im_cmd", options.set_im_cmd)
	end

	-- Events
	if options.restore_events and #options.restore_events > 0 then
		health.ok("restore_events configured")
	else
		health.warn("restore_events is empty; input methods will not be restored automatically")
	end

	if options.remember_events and #options.remember_events > 0 then
		health.ok("remember_events configured")
	else
		health.warn("remember_events is empty; input methods will not be remembered automatically")
	end

	-- Buffer exclusion
	health.ok("Floating windows and special buffer types are automatically excluded")
end

return M
