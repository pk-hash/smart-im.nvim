---@module "luassert"

describe("smart-im behavior simulation", function()
	local mock_im_state = {
		current = "en-US",
		history = {},
	}

	local function create_mock_utils()
		return {
			detect_commands = function()
				return {
					get = "mock-get",
					set = "mock-set %s",
				}
			end,
			execute = function(cmd)
				if cmd == "mock-get" then
					table.insert(mock_im_state.history, { action = "get", result = mock_im_state.current })
					return mock_im_state.current
				elseif cmd:match("^mock%-set ") then
					local im = cmd:match("^mock%-set (.+)$")
					table.insert(mock_im_state.history, { action = "set", value = im })
					mock_im_state.current = im
					return ""
				end
				return ""
			end,
		}
	end

	before_each(function()
		-- Reset modules
		package.loaded["smart-im"] = nil
		package.loaded["smart-im.config"] = nil
		package.loaded["smart-im.state"] = nil
		package.loaded["smart-im.im"] = nil
		package.loaded["smart-im.utils"] = nil
		package.loaded["smart-im.setup"] = nil

		-- Reset mock state
		mock_im_state.current = "en-US"
		mock_im_state.history = {}

		-- Inject mock utils
		package.loaded["smart-im.utils"] = create_mock_utils()
	end)

	describe("workflow: markdown-only tracking", function()
		it("scenario: edit markdown, switch to Chinese, switch files, return", function()
			-- Setup: track only markdown
			require("smart-im").setup({
				default_im = "en-US",
				save_im_for_filetypes = { "markdown" },
			})

			local smart_im = require("smart-im")
			local state = require("smart-im.state")

			-- Step 1: Open markdown file, enter insert mode
			vim.bo.filetype = "markdown"
			smart_im.restore_im() -- First time, should use default

			assert.equals("en-US", mock_im_state.current, "Initial restore should set default")
			assert.equals(1, #mock_im_state.history, "Should have called set once")
			assert.equals("set", mock_im_state.history[1].action)
			assert.equals("en-US", mock_im_state.history[1].value)

			-- Step 2: User manually switches to Chinese
			mock_im_state.current = "zh-CN"

			-- Step 3: Leave insert mode (should remember)
			smart_im.remember_im()

			assert.equals("zh-CN", state.per_filetype.markdown, "Should remember Chinese for markdown")

			-- Step 4: Switch to default on leave
			smart_im.switch_to_default()
			assert.equals("en-US", mock_im_state.current, "Should switch back to default")

			-- Step 5: Switch to lua file
			vim.bo.filetype = "lua"
			smart_im.restore_im()

			assert.equals("en-US", mock_im_state.current, "Lua should use default (not tracked)")
			assert.is_nil(state.per_filetype.lua, "Should not have lua in state")

			-- Step 6: User types in Japanese
			mock_im_state.current = "ja-JP"

			-- Step 7: Leave insert mode in lua
			smart_im.remember_im() -- Should NOT remember (lua not tracked)

			assert.is_nil(state.per_filetype.lua, "Should still not remember lua")

			-- Step 8: Return to markdown
			vim.bo.filetype = "markdown"
			mock_im_state.history = {} -- Clear history to track this restore
			smart_im.restore_im()

			-- Should restore Chinese!
			assert.equals("zh-CN", mock_im_state.current, "Should restore Chinese for markdown")
			assert.equals(1, #mock_im_state.history, "Should have called set")
			assert.equals("set", mock_im_state.history[1].action)
			assert.equals("zh-CN", mock_im_state.history[1].value)
		end)
	end)

	describe("workflow: track all filetypes", function()
		it("scenario: must specify filetypes to track", function()
			require("smart-im").setup({
				default_im = "en-US",
				save_im_for_filetypes = { "markdown", "lua", "python" }, -- Track these
			})

			local smart_im = require("smart-im")
			local state = require("smart-im.state")

			-- Markdown with Chinese
			vim.bo.filetype = "markdown"
			mock_im_state.current = "zh-CN"
			smart_im.remember_im()
			assert.equals("zh-CN", state.per_filetype.markdown)

			-- Lua with Japanese
			vim.bo.filetype = "lua"
			mock_im_state.current = "ja-JP"
			smart_im.remember_im()
			assert.equals("ja-JP", state.per_filetype.lua, "Should track lua when in list")

			-- Python with Korean
			vim.bo.filetype = "python"
			mock_im_state.current = "ko-KR"
			smart_im.remember_im()
			assert.equals("ko-KR", state.per_filetype.python)

			-- Rust (not in list) should not be tracked
			vim.bo.filetype = "rust"
			mock_im_state.current = "ru-RU"
			smart_im.remember_im()
			assert.is_nil(state.per_filetype.rust, "Should not track rust (not in list)")

			-- Restore each one
			vim.bo.filetype = "markdown"
			smart_im.restore_im()
			assert.equals("zh-CN", mock_im_state.current)

			vim.bo.filetype = "lua"
			smart_im.restore_im()
			assert.equals("ja-JP", mock_im_state.current)

			vim.bo.filetype = "python"
			smart_im.restore_im()
			assert.equals("ko-KR", mock_im_state.current)

			-- Rust should use global state (ru-RU was remembered)
			vim.bo.filetype = "rust"
			smart_im.restore_im()
			assert.equals("ru-RU", mock_im_state.current, "Untracked filetype should use global state")

			-- Go (also untracked) should also use global state
			vim.bo.filetype = "go"
			smart_im.restore_im()
			assert.equals("ru-RU", mock_im_state.current, "Another untracked filetype should use same global state")
		end)
	end)

	describe("workflow: config options", function()
		it("restore_previous = false doesn't restore", function()
			require("smart-im").setup({
				default_im = "en-US",
				restore_previous = false,
				save_im_for_filetypes = { "markdown" },
			})

			local smart_im = require("smart-im")
			local state = require("smart-im.state")

			-- Remember Chinese for markdown
			vim.bo.filetype = "markdown"
			mock_im_state.current = "zh-CN"
			smart_im.remember_im()
			assert.equals("zh-CN", state.per_filetype.markdown)

			-- Change to Japanese
			mock_im_state.current = "ja-JP"

			-- Try to restore - should do nothing
			mock_im_state.history = {}
			smart_im.restore_im()

			assert.equals("ja-JP", mock_im_state.current, "Should not restore")
			assert.equals(0, #mock_im_state.history, "Should not call set")
		end)

		it("switch_on_leave = false doesn't switch", function()
			require("smart-im").setup({
				default_im = "en-US",
				switch_on_leave = false,
			})

			local smart_im = require("smart-im")

			mock_im_state.current = "zh-CN"
			mock_im_state.history = {}

			smart_im.switch_to_default()

			assert.equals("zh-CN", mock_im_state.current, "Should not switch")
			assert.equals(0, #mock_im_state.history, "Should not call set")
		end)
	end)

	describe("edge cases", function()
		it("handles empty filetype", function()
			require("smart-im").setup({
				default_im = "en-US",
			})

			local smart_im = require("smart-im")
			local state = require("smart-im.state")

			vim.bo.filetype = ""
			mock_im_state.current = "zh-CN"

			smart_im.remember_im() -- Should not remember

			assert.equals(0, vim.tbl_count(state.per_filetype), "Should not remember empty filetype")
		end)

		it("handles nil filetype", function()
			require("smart-im").setup({
				default_im = "en-US",
			})

			local smart_im = require("smart-im")

			vim.bo.filetype = nil
			mock_im_state.history = {}

			-- Should not crash
			smart_im.remember_im()
			smart_im.restore_im()

			-- restore should set default
			assert.equals("en-US", mock_im_state.current)
		end)

		it("uses default when no remembered IM exists", function()
			require("smart-im").setup({
				default_im = "en-US",
			})

			local smart_im = require("smart-im")

			vim.bo.filetype = "rust" -- Never seen before
			mock_im_state.current = "zh-CN" -- Currently something else
			mock_im_state.history = {}

			smart_im.restore_im() -- Should set default

			assert.equals("en-US", mock_im_state.current)
			assert.equals(1, #mock_im_state.history)
			assert.equals("set", mock_im_state.history[1].action)
			assert.equals("en-US", mock_im_state.history[1].value)
		end)

		it("get_current_im returns nil doesn't break remember", function()
			-- Mock utils that returns nil
			package.loaded["smart-im.utils"] = {
				detect_commands = function()
					return { get = "mock-get", set = "mock-set %s" }
				end,
				execute = function(cmd)
					if cmd == "mock-get" then
						return nil -- Command failed
					end
					return ""
				end,
			}

			require("smart-im").setup({ default_im = "en-US" })

			local smart_im = require("smart-im")
			local state = require("smart-im.state")

			vim.bo.filetype = "markdown"
			smart_im.remember_im() -- Should not crash

			assert.equals(0, vim.tbl_count(state.per_filetype), "Should not save nil IM")
		end)
	end)

	describe("state operations", function()
		it("clear_memory removes specific filetype", function()
			require("smart-im").setup({ default_im = "en-US" })

			local smart_im = require("smart-im")
			local state = require("smart-im.state")

			-- Set up state
			state.set("markdown", "zh-CN")
			state.set("lua", "ja-JP")
			state.set("python", "ko-KR")

			smart_im.clear_memory("lua")

			assert.equals("zh-CN", state.per_filetype.markdown)
			assert.is_nil(state.per_filetype.lua)
			assert.equals("ko-KR", state.per_filetype.python)
		end)

		it("clear_memory with no args removes all", function()
			require("smart-im").setup({ default_im = "en-US" })

			local smart_im = require("smart-im")
			local state = require("smart-im.state")

			state.set("markdown", "zh-CN")
			state.set("lua", "ja-JP")

			smart_im.clear_memory()

			assert.equals(0, vim.tbl_count(state.per_filetype))
		end)

		it("get_state returns deep copy", function()
			require("smart-im").setup({ default_im = "en-US" })

			local smart_im = require("smart-im")
			local state = require("smart-im.state")

			state.set("markdown", "zh-CN")

			local copy1 = smart_im.get_state()
			copy1.markdown = "modified"

			local copy2 = smart_im.get_state()
			assert.equals("zh-CN", copy2.markdown, "Should not affect original")
		end)
	end)
end)
