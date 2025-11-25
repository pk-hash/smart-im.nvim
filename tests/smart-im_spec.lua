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

		it("WinLeave on terminal - remembers IM", function()
			local get_stub, execute_stub = setup_with_mocks()
			local state = require("smart-im.state")

			-- Create actual terminal buffer
			vim.cmd("terminal")
			local bufnr = vim.api.nvim_get_current_buf()

			mock_im_state = "com.apple.keylayout.Russian"

			vim.api.nvim_exec_autocmds("WinLeave", { group = "SmartIM" })

			assert.equals("com.apple.keylayout.Russian", state.get().per_buffer[bufnr])

			vim.api.nvim_buf_delete(bufnr, { force = true })
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

		it("WinLeave on terminal - remembers IM", function()
			local get_stub, execute_stub = setup_with_mocks()
			local state = require("smart-im.state")

			-- Create actual terminal buffer
			vim.cmd("terminal")
			local bufnr = vim.api.nvim_get_current_buf()

			mock_im_state = "com.apple.keylayout.Russian"

			vim.api.nvim_exec_autocmds("WinLeave", { group = "SmartIM", buffer = bufnr })

			assert.equals("com.apple.keylayout.Russian", state.get().per_buffer[bufnr])

			vim.api.nvim_buf_delete(bufnr, { force = true })
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
end)
