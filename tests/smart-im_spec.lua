---@module "luassert"
local DEFAULT_IM = "com.apple.keylayout.US"

describe("smart-im.nvim", function()
before_each(function()
-- Reset modules
package.loaded["smart-im"] = nil
package.loaded["smart-im.config"] = nil
package.loaded["smart-im.state"] = nil
package.loaded["smart-im.im"] = nil
package.loaded["smart-im.utils"] = nil
package.loaded["smart-im.setup"] = nil
end)

describe("setup", function()
it("initializes without errors", function()
assert.has_no.errors(function()
require("smart-im").setup({
default_im = DEFAULT_IM,
get_im_cmd = "echo test",
set_im_cmd = "echo %s",
})
end)
end)

it("creates autocmds", function()
require("smart-im").setup({
default_im = DEFAULT_IM,
get_im_cmd = "echo test",
set_im_cmd = "echo %s",
})

local autocmds = vim.api.nvim_get_autocmds({ group = "SmartIM" })
assert.is_true(#autocmds > 0, "Should have autocmds")
end)

it("creates user commands", function()
require("smart-im").setup({
default_im = DEFAULT_IM,
get_im_cmd = "echo test",
set_im_cmd = "echo %s",
})

local commands = vim.api.nvim_get_commands({})
assert.is_not_nil(commands.SmartIMClear)
assert.is_not_nil(commands.SmartIMStatus)
end)
end)

describe("state management", function()
it("remembers and clears IM", function()
require("smart-im").setup({
default_im = DEFAULT_IM,
get_im_cmd = "echo test-im",
set_im_cmd = "echo %s",
})

local state = require("smart-im.state")
state.set(1, "test-im")
assert.equals("test-im", state.get().per_buffer[1])

state.clear()
assert.is_nil(state.get().per_buffer[1])
end)
end)
end)
