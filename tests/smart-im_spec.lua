---@module "luassert"
local stub = require("luassert.stub")
local DEFAULT_IM = "com.apple.keylayout.US"

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
			})

			local smart_im = require("smart-im")
			local state = require("smart-im.state")

			local bufnr = vim.api.nvim_get_current_buf()
			vim.bo.filetype = "markdown"
			smart_im.remember_im(bufnr)

			local status = state.get()
			assert.equals("zh-CN", status.per_buffer[bufnr])
		end)

		it("remembers and restores IM correctly", function()
			require("smart-im").setup({
				get_im_cmd = "echo zh-CN",
				set_im_cmd = "echo %s",
			})

			local smart_im = require("smart-im")
			local state = require("smart-im.state")

			-- Remember for lua buffer
			local lua_buf = vim.api.nvim_get_current_buf()
			vim.bo.filetype = "lua"
			smart_im.remember_im(lua_buf)

			local status = state.get()
			assert.equals("zh-CN", status.per_buffer[lua_buf], "Should remember IM for buffer")

			-- Remember for markdown buffer
			local md_buf = vim.api.nvim_create_buf(true, false)
			vim.api.nvim_set_current_buf(md_buf)
			vim.bo.filetype = "markdown"
			smart_im.remember_im(md_buf)

			status = state.get()
			assert.equals("zh-CN", status.per_buffer[md_buf], "Should remember IM for buffer")
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

			state.set(1, "im1")
			state.set(2, "im2")
			state.current_im = "im-current"

			vim.api.nvim_cmd({ cmd = "SmartIMClear" }, {})

			assert.equals(0, vim.tbl_count(state.per_buffer))
			assert.is_nil(state.current_im)
		end)
	end)

	describe("state management", function()
		it("can set and get buffer IM", function()
			local state = require("smart-im.state")

			state.set(1, "com.apple.inputmethod.SCIM.ITABC")
			local status = state.get()

			assert.equals("com.apple.inputmethod.SCIM.ITABC", status.per_buffer[1])
		end)

		it("can clear specific buffer", function()
			local state = require("smart-im.state")

			state.set(1, "im1")
			state.set(2, "im2")
			state.clear(1)

			local status = state.get()
			assert.is_nil(status.per_buffer[1])
			assert.equals("im2", status.per_buffer[2])
		end)

		it("can clear all buffers", function()
			local state = require("smart-im.state")

			state.set(1, "im1")
			state.set(2, "im2")
			state.clear()

			local status = state.get()
			assert.equals(0, vim.tbl_count(status.per_buffer))
		end)

		it("returns deep copy of state", function()
			local state = require("smart-im.state")

			state.set(1, "im1")
			local status1 = state.get()
			status1.per_buffer[1] = "modified"

			local status2 = state.get()
			assert.equals("im1", status2.per_buffer[1])
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
			assert.is_nil(config.defaults.get_im_cmd)
			assert.is_nil(config.defaults.set_im_cmd)
		end)

		it("merges user options with defaults", function()
			local config = require("smart-im.config")

			config.setup({
				default_im = "custom.im",
				debug = false,
				get_im_cmd = "custom-get",
				set_im_cmd = "custom-set %s",
			})

			assert.equals("custom.im", config.options.default_im)
			assert.is_false(config.options.debug)
			assert.equals("custom-get", config.options.get_im_cmd)
		end)

		it("does not mutate defaults between setups", function()
			local config = require("smart-im.config")

			config.setup({
				default_im = "custom.im",
				debug = false,
				get_im_cmd = "custom-get",
				set_im_cmd = "custom-set %s",
			})

			assert.equals("custom.im", config.options.default_im)

			config.setup({
				default_im = DEFAULT_IM,
				debug = false,
				get_im_cmd = "echo test",
				set_im_cmd = "echo %s",
			})

			assert.equals(DEFAULT_IM, config.options.default_im)
		end)
	end)

	describe("buffer tracking", function()
		it("stores IM per buffer by default", function()
			require("smart-im").setup({
				get_im_cmd = "echo test.im",
				set_im_cmd = "echo %s",
			})

			local smart_im = require("smart-im")
			local state = require("smart-im.state")

			local buf1 = vim.api.nvim_get_current_buf()
			vim.bo.filetype = "markdown"
			smart_im.remember_im(buf1)

			local buf2 = vim.api.nvim_create_buf(true, false)
			vim.api.nvim_set_current_buf(buf2)
			vim.bo.filetype = "lua"
			smart_im.remember_im(buf2)

			assert.equals("test.im", state.per_buffer[buf1], "Should remember IM for first buffer")
			assert.equals("test.im", state.per_buffer[buf2], "Should remember IM separately per buffer")
		end)

		it("stores IM per buffer", function()
			require("smart-im").setup({
				get_im_cmd = "echo test.im",
				set_im_cmd = "echo %s",
			})

			local smart_im = require("smart-im")
			local state = require("smart-im.state")

			local normal_buf = vim.api.nvim_get_current_buf()
			vim.bo.filetype = "markdown"
			smart_im.remember_im(normal_buf)

			assert.equals("test.im", state.per_buffer[normal_buf], "Should remember normal buffer")
		end)
	end)
end)
