---@module "luassert"
local assert = require("luassert")
local stub = require("luassert.stub")
local match = require("luassert.match")

local DEFAULT_IM = "com.apple.keylayout.US"

describe("smart-im.nvim", function()
	local mock_im_state = DEFAULT_IM

	before_each(function()
		-- Reset modules
		package.loaded["smart-im"] = nil
		package.loaded["smart-im.config"] = nil
		package.loaded["smart-im.state"] = nil
		package.loaded["smart-im.im"] = nil
		package.loaded["smart-im.utils"] = nil
		package.loaded["smart-im.setup"] = nil

		-- Reset mock state
		mock_im_state = DEFAULT_IM
	end)

	local function setup_with_mocks()
		require("smart-im").setup({
			default_im = DEFAULT_IM,
			get_im_cmd = "echo test",
			set_im_cmd = "echo %s",
		})

		local im = require("smart-im.im")
		local utils = require("smart-im.utils")

		local get_stub = stub(im, "get_current_im")
		get_stub.invokes(function()
			return mock_im_state
		end)

		local execute_stub = stub(utils, "execute")
		execute_stub.invokes(function(cmd)
			local set_im = cmd:match("^echo (.+)$")
			if set_im and set_im ~= "test" then
				mock_im_state = set_im
			end
			return "", true
		end)

		return get_stub, execute_stub
	end

	describe("setup", function()
		it("creates autocmds and commands", function()
			require("smart-im").setup({
				default_im = DEFAULT_IM,
				get_im_cmd = "echo test",
				set_im_cmd = "echo %s",
			})

			local autocmds = vim.api.nvim_get_autocmds({ group = "SmartIM" })
			assert.is_true(#autocmds > 0)

			local commands = vim.api.nvim_get_commands({})
			assert.is_not_nil(commands.SmartIMClear)
			assert.is_not_nil(commands.SmartIMStatus)
		end)
	end)

	describe("ModeChanged autocmd integration", function()
		it("i:n transition - remembers IM and switches to default", function()
			local get_stub, execute_stub = setup_with_mocks()
			local state = require("smart-im.state")
			local bufnr = vim.api.nvim_create_buf(true, false)
			vim.api.nvim_set_current_buf(bufnr)

			mock_im_state = "com.apple.keylayout.Russian"

			-- First trigger InsertEnter to set last_insert_buf
			vim.api.nvim_exec_autocmds("InsertEnter", { group = "SmartIM" })

			-- Then trigger i:n transition
			vim.api.nvim_exec_autocmds("ModeChanged", {
				group = "SmartIM",
				pattern = "i:n",
			})

			assert.equals("com.apple.keylayout.Russian", state.get().per_buffer[bufnr])
			assert.stub(execute_stub).was.called_with(match.matches("echo com%.apple%.keylayout%.US"))

			get_stub:revert()
			execute_stub:revert()
		end)

		it("n:i transition - restores saved IM", function()
			local get_stub, execute_stub = setup_with_mocks()
			local state = require("smart-im.state")
			local bufnr = vim.api.nvim_create_buf(true, false)
			vim.api.nvim_set_current_buf(bufnr)

			state.set(bufnr, "com.apple.keylayout.Russian")
			mock_im_state = DEFAULT_IM

			vim.api.nvim_exec_autocmds("ModeChanged", {
				group = "SmartIM",
				pattern = "n:i",
			})

			assert.stub(execute_stub).was.called_with(match.matches("echo com%.apple%.keylayout%.Russian"))

			get_stub:revert()
			execute_stub:revert()
		end)

		it("t:nt transition - remembers IM and switches to default", function()
			local get_stub, execute_stub = setup_with_mocks()
			local state = require("smart-im.state")

			-- Create actual terminal buffer
			vim.cmd("terminal")
			local bufnr = vim.api.nvim_get_current_buf()

			mock_im_state = "com.apple.keylayout.Russian"

			vim.api.nvim_exec_autocmds("ModeChanged", {
				group = "SmartIM",
				pattern = "t:nt",
			})

			assert.equals("com.apple.keylayout.Russian", state.get().per_buffer[bufnr])
			assert.stub(execute_stub).was.called_with(match.matches("echo com%.apple%.keylayout%.US"))

			vim.api.nvim_buf_delete(bufnr, { force = true })
			get_stub:revert()
			execute_stub:revert()
		end)

		it("nt:t transition - restores terminal IM", function()
			local get_stub, execute_stub = setup_with_mocks()
			local state = require("smart-im.state")

			-- Create actual terminal buffer
			vim.cmd("terminal")
			local bufnr = vim.api.nvim_get_current_buf()

			state.set(bufnr, "com.apple.keylayout.Russian")
			mock_im_state = DEFAULT_IM

			vim.api.nvim_exec_autocmds("ModeChanged", {
				group = "SmartIM",
				pattern = "nt:t",
			})

			assert.stub(execute_stub).was.called_with(match.matches("echo com%.apple%.keylayout%.Russian"))

			vim.api.nvim_buf_delete(bufnr, { force = true })
			get_stub:revert()
			execute_stub:revert()
		end)

		it("WinLeave on terminal in terminal mode - remembers IM", function()
			local get_stub, execute_stub = setup_with_mocks()
			local state = require("smart-im.state")

			-- Create actual terminal buffer
			vim.cmd("terminal")
			local bufnr = vim.api.nvim_get_current_buf()

			mock_im_state = "com.apple.keylayout.Russian"

			-- Mock being in terminal mode
			local mode_stub = stub(vim.api, "nvim_get_mode")
			mode_stub.returns({ mode = "t" })

			vim.api.nvim_exec_autocmds("WinLeave", { group = "SmartIM" })

			assert.equals("com.apple.keylayout.Russian", state.get().per_buffer[bufnr])

			vim.api.nvim_buf_delete(bufnr, { force = true })
			mode_stub:revert()
			get_stub:revert()
			execute_stub:revert()
		end)

		it("WinLeave on non-terminal - does nothing", function()
			local get_stub, execute_stub = setup_with_mocks()
			local state = require("smart-im.state")
			local bufnr = vim.api.nvim_create_buf(true, false)
			vim.api.nvim_set_current_buf(bufnr)

			mock_im_state = "com.apple.keylayout.Russian"

			vim.api.nvim_exec_autocmds("WinLeave", { group = "SmartIM" })

			assert.is_nil(state.get().per_buffer[bufnr])

			get_stub:revert()
			execute_stub:revert()
		end)

		it("BufDelete - cleans up buffer data", function()
			local get_stub, execute_stub = setup_with_mocks()
			local state = require("smart-im.state")
			local bufnr = vim.api.nvim_create_buf(true, false)

			state.set(bufnr, "com.apple.keylayout.Russian")
			assert.equals("com.apple.keylayout.Russian", state.get().per_buffer[bufnr])

			vim.api.nvim_exec_autocmds("BufDelete", { group = "SmartIM", buffer = bufnr })

			assert.is_nil(state.get().per_buffer[bufnr])

			get_stub:revert()
			execute_stub:revert()
		end)

		it("does not remember default IM", function()
			local get_stub, execute_stub = setup_with_mocks()
			local state = require("smart-im.state")
			local bufnr = vim.api.nvim_create_buf(true, false)
			vim.api.nvim_set_current_buf(bufnr)

			mock_im_state = DEFAULT_IM

			vim.api.nvim_exec_autocmds("InsertEnter", { group = "SmartIM" })
			vim.api.nvim_exec_autocmds("ModeChanged", {
				group = "SmartIM",
				pattern = "i:n",
			})

			assert.is_nil(state.get().per_buffer[bufnr])

			get_stub:revert()
			execute_stub:revert()
		end)

		it("full workflow - insert to normal to insert restores IM", function()
			local get_stub, execute_stub = setup_with_mocks()
			local state = require("smart-im.state")
			local bufnr = vim.api.nvim_create_buf(true, false)
			vim.api.nvim_set_current_buf(bufnr)

			-- Start with Russian, trigger InsertEnter first
			mock_im_state = "com.apple.keylayout.Russian"
			vim.api.nvim_exec_autocmds("InsertEnter", { group = "SmartIM" })

			-- Leave insert mode (should remember Russian and switch to default)
			vim.api.nvim_exec_autocmds("ModeChanged", {
				group = "SmartIM",
				pattern = "i:n",
			})
			assert.equals("com.apple.keylayout.Russian", state.get().per_buffer[bufnr])
			assert.stub(execute_stub).was.called_with(match.matches("echo com%.apple%.keylayout%.US"))

			-- Enter insert mode again (should restore Russian)
			execute_stub:clear()
			mock_im_state = DEFAULT_IM
			vim.api.nvim_exec_autocmds("ModeChanged", {
				group = "SmartIM",
				pattern = "n:i",
			})
			assert.stub(execute_stub).was.called_with(match.matches("echo com%.apple%.keylayout%.Russian"))

			get_stub:revert()
			execute_stub:revert()
		end)

		it("terminal workflow - remembers and restores terminal IM", function()
			local get_stub, execute_stub = setup_with_mocks()
			local state = require("smart-im.state")

			-- Create actual terminal buffer
			vim.cmd("terminal")
			local bufnr = vim.api.nvim_get_current_buf()

			-- In terminal mode with Russian
			mock_im_state = "com.apple.keylayout.Russian"

			-- Leave terminal mode (should remember and switch to default)
			vim.api.nvim_exec_autocmds("ModeChanged", {
				group = "SmartIM",
				pattern = "t:nt",
			})
			assert.equals("com.apple.keylayout.Russian", state.get().per_buffer[bufnr])
			assert.stub(execute_stub).was.called_with(match.matches("echo com%.apple%.keylayout%.US"))

			-- Enter terminal mode again (should restore Russian)
			execute_stub:clear()
			mock_im_state = DEFAULT_IM
			vim.api.nvim_exec_autocmds("ModeChanged", {
				group = "SmartIM",
				pattern = "nt:t",
			})
			assert.stub(execute_stub).was.called_with(match.matches("echo com%.apple%.keylayout%.Russian"))

			vim.api.nvim_buf_delete(bufnr, { force = true })
			get_stub:revert()
			execute_stub:revert()
		end)

		it("WinLeave on terminal in terminal mode - remembers IM", function()
			local get_stub, execute_stub = setup_with_mocks()
			local state = require("smart-im.state")

			-- Create actual terminal buffer
			vim.cmd("terminal")
			local bufnr = vim.api.nvim_get_current_buf()

			mock_im_state = "com.apple.keylayout.Russian"

			-- Mock being in terminal mode
			local mode_stub = stub(vim.api, "nvim_get_mode")
			mode_stub.returns({ mode = "t" })

			vim.api.nvim_exec_autocmds("WinLeave", { group = "SmartIM", buffer = bufnr })

			assert.equals("com.apple.keylayout.Russian", state.get().per_buffer[bufnr])

			vim.api.nvim_buf_delete(bufnr, { force = true })
			mode_stub:revert()
			get_stub:revert()
			execute_stub:revert()
		end)

		it("WinLeave on non-terminal - does nothing", function()
			local get_stub, execute_stub = setup_with_mocks()
			local state = require("smart-im.state")
			local bufnr = vim.api.nvim_create_buf(true, false)
			vim.api.nvim_set_current_buf(bufnr)

			mock_im_state = "com.apple.keylayout.Russian"

			vim.api.nvim_exec_autocmds("WinLeave", { group = "SmartIM", buffer = bufnr })

			assert.is_nil(state.get().per_buffer[bufnr])

			get_stub:revert()
			execute_stub:revert()
		end)

		it("BufDelete - cleans up buffer data", function()
			local get_stub, execute_stub = setup_with_mocks()
			local state = require("smart-im.state")
			local bufnr = vim.api.nvim_create_buf(true, false)

			state.set(bufnr, "com.apple.keylayout.Russian")
			assert.equals("com.apple.keylayout.Russian", state.get().per_buffer[bufnr])

			vim.api.nvim_exec_autocmds("BufDelete", { group = "SmartIM", buffer = bufnr })

			assert.is_nil(state.get().per_buffer[bufnr])

			get_stub:revert()
			execute_stub:revert()
		end)

		it("does not remember default IM", function()
			local get_stub, execute_stub = setup_with_mocks()
			local state = require("smart-im.state")
			local bufnr = vim.api.nvim_create_buf(true, false)
			vim.api.nvim_set_current_buf(bufnr)

			mock_im_state = DEFAULT_IM

			vim.api.nvim_exec_autocmds("InsertEnter", { group = "SmartIM" })
			vim.api.nvim_exec_autocmds("ModeChanged", {
				group = "SmartIM",
				pattern = "i:n",
			})

			assert.is_nil(state.get().per_buffer[bufnr])

			get_stub:revert()
			execute_stub:revert()
		end)

		it("full workflow - insert to normal to insert restores IM", function()
			local get_stub, execute_stub = setup_with_mocks()
			local state = require("smart-im.state")
			local bufnr = vim.api.nvim_create_buf(true, false)
			vim.api.nvim_set_current_buf(bufnr)

			-- Start with Russian, trigger InsertEnter first
			mock_im_state = "com.apple.keylayout.Russian"
			vim.api.nvim_exec_autocmds("InsertEnter", { group = "SmartIM" })

			-- Leave insert mode (should remember Russian and switch to default)
			vim.api.nvim_exec_autocmds("ModeChanged", {
				group = "SmartIM",
				pattern = "i:n",
			})
			assert.equals("com.apple.keylayout.Russian", state.get().per_buffer[bufnr])
			assert.stub(execute_stub).was.called_with(match.matches("echo com%.apple%.keylayout%.US"))

			-- Enter insert mode again (should restore Russian)
			execute_stub:clear()
			mock_im_state = DEFAULT_IM
			vim.api.nvim_exec_autocmds("ModeChanged", {
				group = "SmartIM",
				pattern = "n:i",
			})
			assert.stub(execute_stub).was.called_with(match.matches("echo com%.apple%.keylayout%.Russian"))

			get_stub:revert()
			execute_stub:revert()
		end)

		it("terminal workflow - remembers and restores terminal IM", function()
			local get_stub, execute_stub = setup_with_mocks()
			local state = require("smart-im.state")

			-- Create actual terminal buffer
			vim.cmd("terminal")
			local bufnr = vim.api.nvim_get_current_buf()

			-- In terminal mode with Russian
			mock_im_state = "com.apple.keylayout.Russian"

			-- Leave terminal mode (should remember and switch to default)
			vim.api.nvim_exec_autocmds("ModeChanged", {
				group = "SmartIM",
				pattern = "t:nt",
			})
			assert.equals("com.apple.keylayout.Russian", state.get().per_buffer[bufnr])
			assert.stub(execute_stub).was.called_with(match.matches("echo com%.apple%.keylayout%.US"))

			-- Enter terminal mode again (should restore Russian)
			execute_stub:clear()
			mock_im_state = DEFAULT_IM
			vim.api.nvim_exec_autocmds("ModeChanged", {
				group = "SmartIM",
				pattern = "nt:t",
			})
			assert.stub(execute_stub).was.called_with(match.matches("echo com%.apple%.keylayout%.Russian"))

			vim.api.nvim_buf_delete(bufnr, { force = true })
			get_stub:revert()
			execute_stub:revert()
		end)

		it("leaving terminal in normal mode preserves saved IM", function()
			local get_stub, execute_stub = setup_with_mocks()
			local state = require("smart-im.state")

			-- Create terminal buffer
			vim.cmd("terminal")
			local bufnr = vim.api.nvim_get_current_buf()

			-- Terminal has Russian saved
			mock_im_state = "com.apple.keylayout.Russian"
			vim.api.nvim_exec_autocmds("ModeChanged", {
				group = "SmartIM",
				pattern = "t:nt",
			})
			assert.equals("com.apple.keylayout.Russian", state.get().per_buffer[bufnr])

			-- Now in normal mode (IM is default), leave window
			mock_im_state = DEFAULT_IM
			vim.api.nvim_exec_autocmds("WinLeave", { group = "SmartIM", buffer = bufnr })

			-- Should still have Russian saved, not default
			assert.equals("com.apple.keylayout.Russian", state.get().per_buffer[bufnr])

			vim.api.nvim_buf_delete(bufnr, { force = true })
			get_stub:revert()
			execute_stub:revert()
		end)
	end)

	describe("commands", function()
		it("clears all remembered IMs", function()
			setup_with_mocks()

			local state = require("smart-im.state")
			state.set(1, "test-im-1")
			state.set(2, "test-im-2")

			vim.cmd("SmartIMClear")

			assert.is_nil(state.get().per_buffer[1])
			assert.is_nil(state.get().per_buffer[2])
		end)
	end)

	describe("Hyprland backend", function()
		local function setup_hyprland_mocks()
			-- Mock hyprctl responses
			local mock_layouts = "us, ru, de"
			local mock_keyboard = "at-translated-set-2-keyboard"
			local mock_active_layout_index = 0

			require("smart-im").setup({
				default_im = "us",
				get_im_cmd = "hyprland",
				set_im_cmd = "hyprland",
			})

			-- Mock the hyprland module
			package.loaded["smart-im.hyprland"] = {
				get_current_layout = function()
					local layouts = {}
					for layout in mock_layouts:gmatch("[^,]+") do
						table.insert(layouts, vim.trim(layout))
					end
					return layouts[mock_active_layout_index + 1]
				end,
				switch_layout = function(target)
					local layouts = {}
					for layout in mock_layouts:gmatch("[^,]+") do
						table.insert(layouts, vim.trim(layout))
					end
					for i, layout in ipairs(layouts) do
						if layout == target then
							mock_active_layout_index = i - 1
							return true
						end
					end
					return false
				end,
			}

			return function(layout)
				-- Helper to set layout by name
				local layouts = {}
				for l in mock_layouts:gmatch("[^,]+") do
					table.insert(layouts, vim.trim(l))
				end
				for i, l in ipairs(layouts) do
					if l == layout then
						mock_active_layout_index = i - 1
						return
					end
				end
			end, function()
				-- Helper to get current layout
				local layouts = {}
				for l in mock_layouts:gmatch("[^,]+") do
					table.insert(layouts, vim.trim(l))
				end
				return layouts[mock_active_layout_index + 1]
			end
		end

		it("gets current layout", function()
			local set_layout, get_layout = setup_hyprland_mocks()
			local im = require("smart-im.im")

			set_layout("ru")
			local current = im.get_current_im()

			assert.equals("ru", current)
		end)

		it("switches layout via Hyprland module", function()
			local set_layout, get_layout = setup_hyprland_mocks()
			local im = require("smart-im.im")

			set_layout("us")
			local success = im.set("ru")

			assert.is_true(success)
			assert.equals("ru", get_layout())
		end)

		it("full workflow with Hyprland", function()
			local set_layout, get_layout = setup_hyprland_mocks()
			local state = require("smart-im.state")
			local bufnr = vim.api.nvim_create_buf(true, false)
			vim.api.nvim_set_current_buf(bufnr)

			-- Start with Russian layout
			set_layout("ru")
			vim.api.nvim_exec_autocmds("InsertEnter", { group = "SmartIM" })

			-- Leave insert mode (should remember Russian and switch to default)
			vim.api.nvim_exec_autocmds("ModeChanged", {
				group = "SmartIM",
				pattern = "i:n",
			})

			assert.equals("ru", state.get().per_buffer[bufnr])
			assert.equals("us", get_layout())

			-- Enter insert mode again (should restore Russian)
			vim.api.nvim_exec_autocmds("ModeChanged", {
				group = "SmartIM",
				pattern = "n:i",
			})

			assert.equals("ru", get_layout())
		end)
	end)
end)
