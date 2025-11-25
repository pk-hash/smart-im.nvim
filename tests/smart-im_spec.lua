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
package.loaded["smart-im.autocmds"] = nil

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

describe("autocmd handlers", function()
it("on_insert_leave - remembers IM and switches to default", function()
local get_stub, execute_stub = setup_with_mocks()
local state = require("smart-im.state")
local autocmds = require("smart-im.autocmds")
local bufnr = vim.api.nvim_create_buf(true, false)

mock_im_state = "com.apple.keylayout.Russian"

autocmds.on_insert_enter({ buf = bufnr })
autocmds.on_insert_leave({ buf = bufnr })

assert.equals("com.apple.keylayout.Russian", state.get().per_buffer[bufnr])
assert.stub(execute_stub).was.called_with(match.matches("echo com%.apple%.keylayout%.US"))

get_stub:revert()
execute_stub:revert()
end)

it("on_insert_enter_restore - restores saved IM", function()
local get_stub, execute_stub = setup_with_mocks()
local state = require("smart-im.state")
local autocmds = require("smart-im.autocmds")
local bufnr = vim.api.nvim_create_buf(true, false)

state.set(bufnr, "com.apple.keylayout.Russian")
mock_im_state = DEFAULT_IM

autocmds.on_insert_enter_restore({ buf = bufnr })

assert.stub(execute_stub).was.called_with(match.matches("echo com%.apple%.keylayout%.Russian"))

get_stub:revert()
execute_stub:revert()
end)

it("on_terminal_leave - remembers IM and switches to default", function()
local get_stub, execute_stub = setup_with_mocks()
local state = require("smart-im.state")
local autocmds = require("smart-im.autocmds")
local bufnr = vim.api.nvim_create_buf(true, false)

mock_im_state = "com.apple.keylayout.Russian"

autocmds.on_terminal_leave({ buf = bufnr })

assert.equals("com.apple.keylayout.Russian", state.get().per_buffer[bufnr])
assert.stub(execute_stub).was.called_with(match.matches("echo com%.apple%.keylayout%.US"))

get_stub:revert()
execute_stub:revert()
end)

it("on_terminal_enter - restores terminal IM", function()
local get_stub, execute_stub = setup_with_mocks()
local state = require("smart-im.state")
local autocmds = require("smart-im.autocmds")
local bufnr = vim.api.nvim_create_buf(true, false)

state.set(bufnr, "com.apple.keylayout.Russian")
mock_im_state = DEFAULT_IM

autocmds.on_terminal_enter({ buf = bufnr })

assert.stub(execute_stub).was.called_with(match.matches("echo com%.apple%.keylayout%.Russian"))

get_stub:revert()
execute_stub:revert()
end)

it("on_terminal_to_normal - switches to default", function()
local get_stub, execute_stub = setup_with_mocks()
local autocmds = require("smart-im.autocmds")
local bufnr = vim.api.nvim_create_buf(true, false)

mock_im_state = "com.apple.keylayout.Russian"

autocmds.on_terminal_to_normal({ buf = bufnr })

assert.stub(execute_stub).was.called_with(match.matches("echo com%.apple%.keylayout%.US"))

get_stub:revert()
execute_stub:revert()
end)

it("on_terminal_to_normal - skips prompt buffers", function()
local get_stub, execute_stub = setup_with_mocks()
local autocmds = require("smart-im.autocmds")
local bufnr = vim.api.nvim_create_buf(true, false)
vim.bo[bufnr].buftype = "prompt"

mock_im_state = "com.apple.keylayout.Russian"

autocmds.on_terminal_to_normal({ buf = bufnr })

assert.stub(execute_stub).was_not.called()

get_stub:revert()
execute_stub:revert()
end)

it("on_win_leave - remembers IM for terminal", function()
local get_stub, execute_stub = setup_with_mocks()
local state = require("smart-im.state")
local autocmds = require("smart-im.autocmds")
local bufnr = vim.api.nvim_create_buf(true, false)

-- Stub vim.bo buftype check
local orig_index = getmetatable(vim.bo).__index
getmetatable(vim.bo).__index = function(t, k)
if type(k) == "number" and k == bufnr then
return { buftype = "terminal" }
end
return orig_index(t, k)
end

mock_im_state = "com.apple.keylayout.Russian"

autocmds.on_win_leave({ buf = bufnr })

assert.equals("com.apple.keylayout.Russian", state.get().per_buffer[bufnr])

getmetatable(vim.bo).__index = orig_index
get_stub:revert()
execute_stub:revert()
end)

it("on_win_leave - ignores non-terminal", function()
local get_stub, execute_stub = setup_with_mocks()
local state = require("smart-im.state")
local autocmds = require("smart-im.autocmds")
local bufnr = vim.api.nvim_create_buf(true, false)

mock_im_state = "com.apple.keylayout.Russian"

autocmds.on_win_leave({ buf = bufnr })

assert.is_nil(state.get().per_buffer[bufnr])

get_stub:revert()
execute_stub:revert()
end)

it("on_buf_delete - cleans up buffer data", function()
local get_stub, execute_stub = setup_with_mocks()
local state = require("smart-im.state")
local autocmds = require("smart-im.autocmds")
local bufnr = vim.api.nvim_create_buf(true, false)

state.set(bufnr, "com.apple.keylayout.Russian")
assert.equals("com.apple.keylayout.Russian", state.get().per_buffer[bufnr])

autocmds.on_buf_delete({ buf = bufnr })

assert.is_nil(state.get().per_buffer[bufnr])

get_stub:revert()
execute_stub:revert()
end)

it("does not remember default IM", function()
local get_stub, execute_stub = setup_with_mocks()
local state = require("smart-im.state")
local autocmds = require("smart-im.autocmds")
local bufnr = vim.api.nvim_create_buf(true, false)

mock_im_state = DEFAULT_IM

autocmds.on_insert_enter({ buf = bufnr })
autocmds.on_insert_leave({ buf = bufnr })

assert.is_nil(state.get().per_buffer[bufnr])

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
