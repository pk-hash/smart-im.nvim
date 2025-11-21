---@module "luassert"

describe("smart-im", function()
	before_each(function()
		-- Reset module state
		package.loaded["smart-im"] = nil
		package.loaded["smart-im.config"] = nil
		package.loaded["smart-im.state"] = nil
		package.loaded["smart-im.im"] = nil
		package.loaded["smart-im.utils"] = nil
		package.loaded["smart-im.autocmds"] = nil
		package.loaded["smart-im.commands"] = nil
	end)

	describe("setup", function()
		it("can be initialized with default config", function()
			require("smart-im").setup({
				get_im_cmd = "echo test",
				set_im_cmd = "echo %s",
			})
			local config = require("smart-im.config")
			assert.is_not_nil(config.options)
			assert.equals("com.apple.keylayout.ABC", config.options.default_im)
		end)

		it("accepts custom default_im", function()
			require("smart-im").setup({
				default_im = "custom.im",
				get_im_cmd = "echo test",
				set_im_cmd = "echo %s",
			})
			local config = require("smart-im.config")
			assert.equals("custom.im", config.options.default_im)
		end)

		it("accepts save_im_for_filetypes", function()
			require("smart-im").setup({
				save_im_for_filetypes = { "markdown", "text" },
				get_im_cmd = "echo test",
				set_im_cmd = "echo %s",
			})
			local config = require("smart-im.config")
			assert.equals(2, #config.options.save_im_for_filetypes)
			assert.is_true(vim.tbl_contains(config.options.save_im_for_filetypes, "markdown"))
		end)

		it("accepts boolean options", function()
			require("smart-im").setup({
				restore_previous = false,
				switch_on_leave = false,
				get_im_cmd = "echo test",
				set_im_cmd = "echo %s",
			})
			local config = require("smart-im.config")
			assert.is_false(config.options.restore_previous)
			assert.is_false(config.options.switch_on_leave)
		end)

		it("registers autocmds on setup", function()
			require("smart-im").setup({
				get_im_cmd = "echo test",
				set_im_cmd = "echo %s",
			})

			local autocmds = vim.api.nvim_get_autocmds({ group = "SmartIM" })
			assert.is_true(#autocmds > 0, "Should have autocmds after setup")
		end)

		it("creates user commands", function()
			require("smart-im").setup({
				get_im_cmd = "echo test",
				set_im_cmd = "echo %s",
			})

			local commands = vim.api.nvim_get_commands({})
			assert.is_not_nil(commands.SmartIMStatus)
			assert.is_not_nil(commands.SmartIMClear)
		end)
	end)

	describe("state management", function()
		it("can set and get filetype IM", function()
			local state = require("smart-im.state")

			state.set("markdown", "com.apple.inputmethod.SCIM.ITABC")
			local status = state.get()

			assert.equals("com.apple.inputmethod.SCIM.ITABC", status.markdown)
		end)

		it("can clear specific filetype", function()
			local state = require("smart-im.state")

			state.set("markdown", "im1")
			state.set("text", "im2")
			state.clear("markdown")

			local status = state.get()
			assert.is_nil(status.markdown)
			assert.equals("im2", status.text)
		end)

		it("can clear all filetypes", function()
			local state = require("smart-im.state")

			state.set("markdown", "im1")
			state.set("text", "im2")
			state.clear()

			local status = state.get()
			assert.equals(0, vim.tbl_count(status))
		end)

		it("returns deep copy of state", function()
			local state = require("smart-im.state")

			state.set("markdown", "im1")
			local status1 = state.get()
			status1.markdown = "modified"

			local status2 = state.get()
			assert.equals("im1", status2.markdown)
		end)
	end)

	describe("API", function()
		before_each(function()
			require("smart-im").setup({
				get_im_cmd = "echo test.im",
				set_im_cmd = "echo %s",
			})
		end)

		it("exposes get_current_im", function()
			local smart_im = require("smart-im")
			assert.is_function(smart_im.get_current_im)
		end)

		it("exposes set_im", function()
			local smart_im = require("smart-im")
			assert.is_function(smart_im.set_im)
		end)

		it("exposes remember_im", function()
			local smart_im = require("smart-im")
			assert.is_function(smart_im.remember_im)
		end)

		it("exposes restore_im", function()
			local smart_im = require("smart-im")
			assert.is_function(smart_im.restore_im)
		end)

		it("exposes switch_to_default", function()
			local smart_im = require("smart-im")
			assert.is_function(smart_im.switch_to_default)
		end)

		it("exposes clear_memory", function()
			local smart_im = require("smart-im")
			assert.is_function(smart_im.clear_memory)
		end)

		it("exposes get_state", function()
			local smart_im = require("smart-im")
			assert.is_function(smart_im.get_state)
		end)

		it("exposes set", function()
			local smart_im = require("smart-im")
			assert.is_function(smart_im.set)
		end)
	end)

	describe("utils", function()
		it("detects macOS commands", function()
			local utils = require("smart-im.utils")
			-- Mock os detection
			local original_uname = vim.loop.os_uname
			vim.loop.os_uname = function()
				return { sysname = "Darwin" }
			end

			local cmds = utils.detect_commands()
			assert.equals("im-select", cmds.get)
			assert.equals("im-select %s", cmds.set)

			vim.loop.os_uname = original_uname
		end)

		it("detects Linux IBus commands", function()
			local utils = require("smart-im.utils")
			local original_uname = vim.loop.os_uname
			local original_executable = vim.fn.executable

			vim.loop.os_uname = function()
				return { sysname = "Linux" }
			end
			vim.fn.executable = function(cmd)
				return cmd == "ibus" and 1 or 0
			end

			local cmds = utils.detect_commands()
			assert.equals("ibus engine", cmds.get)
			assert.equals("ibus engine %s", cmds.set)

			vim.loop.os_uname = original_uname
			vim.fn.executable = original_executable
		end)

		it("detects Windows commands", function()
			local utils = require("smart-im.utils")
			local original_uname = vim.loop.os_uname

			vim.loop.os_uname = function()
				return { sysname = "Windows_NT" }
			end

			local cmds = utils.detect_commands()
			assert.equals("im-select.exe", cmds.get)
			assert.equals("im-select.exe %s", cmds.set)

			vim.loop.os_uname = original_uname
		end)
	end)

	describe("config", function()
		it("has correct default values", function()
			local config = require("smart-im.config")

			assert.equals("com.apple.keylayout.ABC", config.defaults.default_im)
			assert.is_true(config.defaults.restore_previous)
			assert.is_true(config.defaults.switch_on_leave)
			assert.equals(0, #config.defaults.save_im_for_filetypes)
			assert.is_nil(config.defaults.get_im_cmd)
			assert.is_nil(config.defaults.set_im_cmd)
		end)

		it("merges user options with defaults", function()
			local config = require("smart-im.config")

			config.setup({
				default_im = "custom.im",
				restore_previous = false,
				get_im_cmd = "custom-get",
				set_im_cmd = "custom-set %s",
			})

			assert.equals("custom.im", config.options.default_im)
			assert.is_false(config.options.restore_previous)
			assert.is_true(config.options.switch_on_leave) -- unchanged default
			assert.equals("custom-get", config.options.get_im_cmd)
		end)
	end)

	describe("filetype tracking", function()
		it("tracks all filetypes by default", function()
			require("smart-im").setup({
				save_im_for_filetypes = {},
				get_im_cmd = "echo test.im",
				set_im_cmd = "echo %s",
			})

			local smart_im = require("smart-im")
			smart_im.set("markdown", "im1")
			smart_im.set("lua", "im2")

			local state = smart_im.get_state()
			assert.equals("im1", state.markdown)
			assert.equals("im2", state.lua)
		end)

		it("tracks only specified filetypes", function()
			require("smart-im").setup({
				save_im_for_filetypes = { "markdown" },
				get_im_cmd = "echo test.im",
				set_im_cmd = "echo %s",
			})

			local smart_im = require("smart-im")
			smart_im.set("markdown", "im1")
			smart_im.set("lua", "im2")

			local state = smart_im.get_state()
			assert.equals("im1", state.markdown)
			assert.equals("im2", state.lua) -- set() bypasses tracking filter
		end)
	end)
end)
