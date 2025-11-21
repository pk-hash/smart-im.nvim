---@module "luassert"
local stub = require("luassert.stub")
local DEFAULT_IM = "com.apple.keylayout.ABC"

describe("smart-im", function()
	before_each(function()
		-- Reset module state
		package.loaded["smart-im"] = nil
		package.loaded["smart-im.config"] = nil
		package.loaded["smart-im.state"] = nil
		package.loaded["smart-im.im"] = nil
		package.loaded["smart-im.utils"] = nil
		package.loaded["smart-im.setup"] = nil
	end)

	describe("integration", function()
		it("auto-detects commands and doesn't lose them", function()
			local os_stub = stub(vim.loop, "os_uname")
			os_stub.returns({ sysname = "Darwin" })

			local exec_stub = stub(vim.fn, "executable")
			exec_stub.invokes(function(cmd)
				return cmd == "im-select" and 1 or 0
			end)

			require("smart-im").setup({
				default_im = "custom.im",
			})

			local config = require("smart-im.config")

			assert.is_not_nil(config.options.get_im_cmd)
			assert.is_not_nil(config.options.set_im_cmd)
			assert.are.equal("im-select", config.options.get_im_cmd)
			assert.are.equal("im-select %s", config.options.set_im_cmd)

			os_stub:revert()
			exec_stub:revert()
		end)

		it("preserves user-provided commands over auto-detection", function()
			local os_stub = stub(vim.loop, "os_uname")
			os_stub.returns({ sysname = "Darwin" })

			require("smart-im").setup({
				default_im = "en-US",
				get_im_cmd = "custom-get",
				set_im_cmd = "custom-set %s",
			})

			local config = require("smart-im.config")
			assert.are.equal("custom-get", config.options.get_im_cmd)
			assert.are.equal("custom-set %s", config.options.set_im_cmd)

			os_stub:revert()
		end)

		it("remembers IM when leaving insert mode", function()
			require("smart-im").setup({
				default_im = "en-US",
				get_im_cmd = "echo zh-CN",
				set_im_cmd = "echo %s",
				remember_filetypes = { "markdown" },
			})

			local smart_im = require("smart-im")
			local state = require("smart-im.state")

			vim.bo.filetype = "markdown"
			smart_im.remember_im()

			local status = state.get()
			assert.equals("zh-CN", status.per_filetype.markdown)
		end)

		it("respects remember_filetypes filter", function()
			require("smart-im").setup({
				remember_filetypes = { "markdown" },
				get_im_cmd = "echo zh-CN",
				set_im_cmd = "echo %s",
			})

			local smart_im = require("smart-im")
			local state = require("smart-im.state")

			-- Try to remember for lua (not in list)
			vim.bo.filetype = "lua"
			smart_im.remember_im()

			local status = state.get()
			assert.is_nil(status.per_filetype.lua, "Should not remember IM for untracked filetype")

			-- Try to remember for markdown (in list)
			vim.bo.filetype = "markdown"
			smart_im.remember_im()

			status = state.get()
			assert.equals("zh-CN", status.per_filetype.markdown, "Should remember IM for tracked filetype")
		end)
	end)

	describe("setup", function()
		it("can be initialized with default config", function()
			require("smart-im").setup({
				get_im_cmd = "echo test",
				set_im_cmd = "echo %s",
			})
			local config = require("smart-im.config")
			assert.is_not_nil(config.options)
			assert.equals(DEFAULT_IM, config.options.default_im)
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

		it("accepts remember_filetypes", function()
			require("smart-im").setup({
				remember_filetypes = { "markdown", "text" },
				get_im_cmd = "echo test",
				set_im_cmd = "echo %s",
			})
			local config = require("smart-im.config")
			assert.equals(2, #config.options.remember_filetypes)
			assert.is_true(vim.tbl_contains(config.options.remember_filetypes, "markdown"))
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

		it("SmartIMClear clears all state", function()
			require("smart-im").setup({
				get_im_cmd = "echo test",
				set_im_cmd = "echo %s",
			})

			local smart_im = require("smart-im")
			local state = require("smart-im.state")

			state.set("markdown", "im1")
			state.set("lua", "im2")
			state.global = "im-global"
			state.current_im = "im-current"

			vim.api.nvim_cmd({ cmd = "SmartIMClear" }, {})

			assert.equals(0, vim.tbl_count(state.per_filetype))
			assert.is_nil(state.global)
			assert.is_nil(state.current_im)
		end)
	end)

	describe("state management", function()
		it("can set and get filetype IM", function()
			local state = require("smart-im.state")

			state.set("markdown", "com.apple.inputmethod.SCIM.ITABC")
			local status = state.get()

			assert.equals("com.apple.inputmethod.SCIM.ITABC", status.per_filetype.markdown)
		end)

		it("can clear specific filetype", function()
			local state = require("smart-im.state")

			state.set("markdown", "im1")
			state.set("text", "im2")
			state.clear("markdown")

			local status = state.get()
			assert.is_nil(status.per_filetype.markdown)
			assert.equals("im2", status.per_filetype.text)
		end)

		it("can clear all filetypes", function()
			local state = require("smart-im.state")

			state.set("markdown", "im1")
			state.set("text", "im2")
			state.clear()

			local status = state.get()
			assert.equals(0, vim.tbl_count(status.per_filetype))
		end)

		it("returns deep copy of state", function()
			local state = require("smart-im.state")

			state.set("markdown", "im1")
			local status1 = state.get()
			status1.per_filetype.markdown = "modified"

			local status2 = state.get()
			assert.equals("im1", status2.per_filetype.markdown)
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

			local os_stub = stub(vim.loop, "os_uname")
			os_stub.returns({ sysname = "Darwin" })

			local exec_stub = stub(vim.fn, "executable")
			exec_stub.invokes(function(cmd)
				return cmd == "im-select" and 1 or 0
			end)

			local cmds = utils.detect_commands()
			assert.are.equal("im-select", cmds and cmds.get)
			assert.are.equal("im-select %s", cmds and cmds.set)

			os_stub:revert()
			exec_stub:revert()
		end)

		it("detects Linux IBus commands", function()
			local utils = require("smart-im.utils")

			local os_stub = stub(vim.loop, "os_uname")
			os_stub.returns({ sysname = "Linux" })

			local exec_stub = stub(vim.fn, "executable")
			exec_stub.invokes(function(cmd)
				return cmd == "ibus" and 1 or 0
			end)

			local cmds = utils.detect_commands()
			assert.are.equal("ibus engine", cmds and cmds.get)
			assert.are.equal("ibus engine %s", cmds and cmds.set)

			os_stub:revert()
			exec_stub:revert()
		end)

		it("detects Windows commands", function()
			local utils = require("smart-im.utils")

			local os_stub = stub(vim.loop, "os_uname")
			os_stub.returns({ sysname = "Windows_NT" })

			local exec_stub = stub(vim.fn, "executable")
			exec_stub.invokes(function(cmd)
				return cmd == "im-select.exe" and 1 or 0
			end)

			local cmds = utils.detect_commands()
			assert.are.equal("im-select.exe", cmds and cmds.get)
			assert.are.equal("im-select.exe %s", cmds and cmds.set)

			os_stub:revert()
			exec_stub:revert()
		end)
	end)

	describe("config", function()
		it("has correct default values", function()
			local config = require("smart-im.config")

			assert.equals(DEFAULT_IM, config.defaults.default_im)
			assert.is_true(config.defaults.restore_previous)
			assert.is_true(config.defaults.switch_on_leave)
			assert.equals(0, #config.defaults.remember_filetypes)
			assert.is_nil(config.defaults.get_im_cmd)
			assert.is_nil(config.defaults.set_im_cmd)
		end)

		it("merges user options with defaults", function()
			local config = require("smart-im.config")

			config.setup({
				default_im = "custom.im",
				restore_previous = false,
				switch_on_leave = true,
				remember_filetypes = {},
				restore_events = { "InsertEnter" },
				remember_events = { "InsertLeave", "CmdlineLeave" },
				debug = false,
				get_im_cmd = "custom-get",
				set_im_cmd = "custom-set %s",
			})

			assert.equals("custom.im", config.options.default_im)
			assert.is_false(config.options.restore_previous)
			assert.is_true(config.options.switch_on_leave) -- unchanged default
			assert.equals("custom-get", config.options.get_im_cmd)
		end)

		it("does not mutate defaults between setups", function()
			local config = require("smart-im.config")

			config.setup({
				default_im = "custom.im",
				restore_previous = false,
				switch_on_leave = true,
				remember_filetypes = {},
				restore_events = { "InsertEnter" },
				remember_events = { "InsertLeave", "CmdlineLeave" },
				debug = false,
				get_im_cmd = "custom-get",
				set_im_cmd = "custom-set %s",
			})

			assert.equals("custom.im", config.options.default_im)
			assert.is_false(config.options.restore_previous)

			config.setup({
				default_im = DEFAULT_IM,
				restore_previous = true,
				switch_on_leave = true,
				remember_filetypes = {},
				restore_events = { "InsertEnter" },
				remember_events = { "InsertLeave", "CmdlineLeave" },
				debug = false,
				get_im_cmd = "echo test",
				set_im_cmd = "echo %s",
			})

			assert.equals(DEFAULT_IM, config.options.default_im)
			assert.is_true(config.options.restore_previous)
		end)
	end)

	describe("filetype tracking", function()
		it("does not track per-filetype when list is empty", function()
			require("smart-im").setup({
				remember_filetypes = {},
				get_im_cmd = "echo test.im",
				set_im_cmd = "echo %s",
			})

			local smart_im = require("smart-im")
			local state = require("smart-im.state")

			vim.bo.filetype = "markdown"
			smart_im.remember_im()

			assert.is_nil(state.per_filetype.markdown, "Should not remember per-filetype")
			assert.equals("test.im", state.global, "Should remember globally for untracked filetypes")
		end)

		it("tracks only specified filetypes", function()
			require("smart-im").setup({
				remember_filetypes = { "markdown" },
				get_im_cmd = "echo test.im",
				set_im_cmd = "echo %s",
			})

			local smart_im = require("smart-im")
			local state = require("smart-im.state")

			vim.bo.filetype = "markdown"
			smart_im.remember_im()

			assert.equals("test.im", state.per_filetype.markdown, "Should track listed filetypes")

			vim.bo.filetype = "lua"
			smart_im.remember_im()

			assert.is_nil(state.per_filetype.lua, "Should not track unlisted filetypes")
			assert.equals("test.im", state.global, "Unlisted filetypes should use global state")
		end)
	end)
end)
