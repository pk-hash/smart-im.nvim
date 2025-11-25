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
					return mock_im_state.current, true
				elseif cmd:match("^mock%-set ") then
					local im = cmd:match("^mock%-set (.+)$")
					table.insert(mock_im_state.history, { action = "set", value = im })
					mock_im_state.current = im
					return "", true
				end
				return "", false
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

	describe("workflow: per-buffer tracking", function()
		it("remembers per buffer and restores correct IM", function()
			require("smart-im").setup({
				default_im = "en-US",
			})

			local smart_im = require("smart-im")
			local state = require("smart-im.state")

			-- Buffer 1 (markdown)
			local buf1 = vim.api.nvim_get_current_buf()
			vim.bo.filetype = "markdown"
			smart_im.restore_im(buf1) -- First time should set default
			assert.equals("en-US", mock_im_state.current)

			mock_im_state.current = "zh-CN"
			smart_im.remember_im(buf1)
			assert.equals("zh-CN", state.per_buffer[buf1])

			-- Buffer 2 (lua)
			local buf2 = vim.api.nvim_create_buf(true, false)
			vim.api.nvim_set_current_buf(buf2)
			vim.bo.filetype = "lua"
			smart_im.restore_im(buf2)
			assert.equals("en-US", mock_im_state.current, "New buffer starts at default")

			mock_im_state.current = "ja-JP"
			smart_im.remember_im(buf2)
			assert.equals("ja-JP", state.per_buffer[buf2])

			-- Return to buffer 1 -> should restore Chinese
			vim.api.nvim_set_current_buf(buf1)
			mock_im_state.history = {}
			smart_im.restore_im(buf1)
			assert.equals("zh-CN", mock_im_state.current)

			-- Return to buffer 2 -> should restore Japanese
			vim.api.nvim_set_current_buf(buf2)
			mock_im_state.history = {}
			smart_im.restore_im(buf2)
			assert.equals("ja-JP", mock_im_state.current)
		end)
	end)

	describe("workflow: tracking", function()
		it("tracks all normal buffers", function()
			require("smart-im").setup({
				default_im = "en-US",
			})

			local smart_im = require("smart-im")
			local state = require("smart-im.state")

			-- Markdown buffer should be tracked
			local md_buf = vim.api.nvim_get_current_buf()
			vim.bo.filetype = "markdown"
			mock_im_state.current = "zh-CN"
			smart_im.remember_im(md_buf)
			assert.equals("zh-CN", state.per_buffer[md_buf])

			-- Lua buffer should be tracked
			local lua_buf = vim.api.nvim_create_buf(true, false)
			vim.api.nvim_set_current_buf(lua_buf)
			vim.bo.filetype = "lua"
			mock_im_state.current = "ru-RU"
			smart_im.remember_im(lua_buf)
			assert.equals("ru-RU", state.per_buffer[lua_buf])

			mock_im_state.current = "en-US"
			mock_im_state.history = {}
			smart_im.restore_im(lua_buf)
			assert.equals("ru-RU", mock_im_state.current, "Tracked buffer restores remembered IM")
		end)
	end)

	describe("workflow: mode transitions", function()
		it("n:i transition restores saved IM", function()
			require("smart-im").setup({ default_im = "en-US" })
			local smart_im = require("smart-im")
			local state = require("smart-im.state")

			local buf = vim.api.nvim_get_current_buf()
			state.set(buf, "zh-CN")

			mock_im_state.current = "en-US"
			smart_im.restore_im(buf)
			assert.equals("zh-CN", mock_im_state.current)
		end)

		it("n:i transition restores default when no saved IM", function()
			require("smart-im").setup({ default_im = "en-US" })
			local smart_im = require("smart-im")

			local buf = vim.api.nvim_get_current_buf()
			mock_im_state.current = "ko-KR"
			smart_im.restore_im(buf)
			assert.equals("en-US", mock_im_state.current)
		end)

		it("i:n transition remembers current IM", function()
			require("smart-im").setup({ default_im = "en-US" })
			local smart_im = require("smart-im")
			local state = require("smart-im.state")

			local buf = vim.api.nvim_get_current_buf()
			mock_im_state.current = "ja-JP"
			smart_im.remember_im(buf)
			assert.equals("ja-JP", state.per_buffer[buf])
		end)

		it("i:n transition doesn't save default IM", function()
			require("smart-im").setup({ default_im = "en-US" })
			local smart_im = require("smart-im")
			local state = require("smart-im.state")

			local buf = vim.api.nvim_get_current_buf()
			-- Set non-default first
			state.set(buf, "zh-CN")
			assert.equals("zh-CN", state.per_buffer[buf])

			-- Now remember default - should clear
			mock_im_state.current = "en-US"
			smart_im.remember_im(buf)
			assert.is_nil(state.per_buffer[buf])
		end)

		it("n:t transition restores terminal IM", function()
			require("smart-im").setup({ default_im = "en-US" })
			local smart_im = require("smart-im")
			local state = require("smart-im.state")

			local buf = vim.api.nvim_get_current_buf()
			state.set(buf, "ko-KR")

			mock_im_state.current = "en-US"
			smart_im.restore_im(buf)
			assert.equals("ko-KR", mock_im_state.current)
		end)

		it("t:n transition remembers terminal IM", function()
			require("smart-im").setup({ default_im = "en-US" })
			local smart_im = require("smart-im")
			local state = require("smart-im.state")

			local buf = vim.api.nvim_get_current_buf()
			mock_im_state.current = "ru-RU"
			smart_im.remember_im(buf)
			assert.equals("ru-RU", state.per_buffer[buf])
		end)

		it("multiple buffers maintain separate IM state", function()
			require("smart-im").setup({ default_im = "en-US" })
			local smart_im = require("smart-im")
			local state = require("smart-im.state")

			local buf1 = vim.api.nvim_get_current_buf()
			local buf2 = vim.api.nvim_create_buf(true, false)

			-- Set different IMs for each buffer
			mock_im_state.current = "zh-CN"
			smart_im.remember_im(buf1)

			mock_im_state.current = "ja-JP"
			smart_im.remember_im(buf2)

			assert.equals("zh-CN", state.per_buffer[buf1])
			assert.equals("ja-JP", state.per_buffer[buf2])

			-- Restore each buffer independently
			mock_im_state.current = "en-US"
			smart_im.restore_im(buf1)
			assert.equals("zh-CN", mock_im_state.current)

			mock_im_state.current = "en-US"
			smart_im.restore_im(buf2)
			assert.equals("ja-JP", mock_im_state.current)
		end)
	end)

	describe("edge cases", function()
		it("remembers buffers with filetype", function()
			require("smart-im").setup({
				default_im = "en-US",
			})

			local smart_im = require("smart-im")
			local state = require("smart-im.state")

			vim.bo.filetype = "lua"
			mock_im_state.current = "zh-CN"

			smart_im.remember_im() -- Should remember

			assert.equals(1, vim.tbl_count(state.per_buffer), "Should remember with filetype")
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

		it("restores default when no remembered IM exists", function()
			require("smart-im").setup({
				default_im = "en-US",
			})

			local smart_im = require("smart-im")

			local buf = vim.api.nvim_get_current_buf()
			vim.bo.filetype = "rust" -- Never seen before
			mock_im_state.current = "zh-CN" -- Currently something else
			mock_im_state.history = {}

			smart_im.restore_im(buf) -- Should set to default

			assert.equals("en-US", mock_im_state.current)
		end)

		it("get_current_im returns nil doesn't break remember", function()
			-- Mock utils that returns nil
			package.loaded["smart-im.utils"] = {
				detect_commands = function()
					return { get = "mock-get", set = "mock-set %s" }
				end,
				execute = function(cmd)
					if cmd == "mock-get" then
						return nil, false -- Command failed
					end
					return "", true
				end,
			}

			require("smart-im").setup({ default_im = "en-US" })

			local smart_im = require("smart-im")
			local state = require("smart-im.state")
			local buf = vim.api.nvim_get_current_buf()

			vim.bo.filetype = "markdown"
			smart_im.remember_im(buf) -- Should not crash

			assert.equals(0, vim.tbl_count(state.per_buffer), "Should not save nil IM")
		end)

		it("set_im returns false and state unchanged when command fails", function()
			package.loaded["smart-im.utils"] = {
				detect_commands = function()
					return { get = "mock-get", set = "mock-set %s" }
				end,
				execute = function(cmd)
					if cmd == "mock-get" then
						return "zh-CN", true
					end
					return "", false
				end,
			}

			require("smart-im").setup({ default_im = "en-US" })

			local smart_im = require("smart-im")
			local state = require("smart-im.state")

			local ok = smart_im.set_im("ja-JP")

			assert.is_false(ok, "set_im should report failure when command fails")
			assert.is_nil(state.current_im, "State should not update when command fails")
		end)
	end)

	describe("state operations", function()
		it("clear_memory removes specific buffer", function()
			require("smart-im").setup({ default_im = "en-US" })

			local smart_im = require("smart-im")
			local state = require("smart-im.state")

			-- Set up state
			state.set(1, "zh-CN")
			state.set(2, "ja-JP")
			state.set(3, "ko-KR")

			smart_im.clear_memory(2)

			assert.equals("zh-CN", state.per_buffer[1])
			assert.is_nil(state.per_buffer[2])
			assert.equals("ko-KR", state.per_buffer[3])
		end)

		it("clear_memory with no args removes all", function()
			require("smart-im").setup({ default_im = "en-US" })

			local smart_im = require("smart-im")
			local state = require("smart-im.state")

			state.set(1, "zh-CN")
			state.set(2, "ja-JP")

			smart_im.clear_memory()

			assert.equals(0, vim.tbl_count(state.per_buffer))
		end)

		it("get_state returns deep copy", function()
			require("smart-im").setup({ default_im = "en-US" })

			local smart_im = require("smart-im")
			local state = require("smart-im.state")

			state.set(1, "zh-CN")

			local copy1 = smart_im.get_state()
			copy1.per_buffer[1] = "modified"

			local copy2 = smart_im.get_state()
			assert.equals("zh-CN", copy2.per_buffer[1], "Should not affect original")
		end)
	end)
end)
