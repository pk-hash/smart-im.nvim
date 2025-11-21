local M = {}

function M.autocmds()
local im = require("smart-im.im")
local group = vim.api.nvim_create_augroup("SmartIM", { clear = true })

vim.api.nvim_create_autocmd("InsertLeave", {
group = group,
callback = function()
im.remember()
im.switch_to_default()
end,
})

vim.api.nvim_create_autocmd("InsertEnter", {
group = group,
callback = function()
im.restore()
end,
})

vim.api.nvim_create_autocmd("BufLeave", {
group = group,
callback = function()
if vim.fn.mode():match("^[iR]") then
im.remember()
end
end,
})
end

function M.commands()
local state = require("smart-im.state")

vim.api.nvim_create_user_command("SmartIMClear", function(args)
state.clear(args.args ~= "" and args.args or nil)
vim.notify("smart-im.nvim: Memory cleared", vim.log.levels.INFO)
end, {
nargs = "?",
desc = "Clear input method memory (optionally for specific filetype)",
})

vim.api.nvim_create_user_command("SmartIMStatus", function()
local status = state.get()
local lines = { "smart-im.nvim status:" }
for ft, im in pairs(status) do
table.insert(lines, string.format("  %s: %s", ft, im))
end
if vim.tbl_isempty(status) then
table.insert(lines, "  (no remembered input methods)")
end
vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end, {
desc = "Show remembered input methods per filetype",
})
end

return M
