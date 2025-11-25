local M = {}

---@type table<integer, string> Per-buffer input method state
M.per_buffer = {}

---@type string? Currently active input method
M.current_im = nil

local function normalize_bufnr(bufnr)
	if not bufnr or bufnr == 0 then
		return vim.api.nvim_get_current_buf()
	end
	return bufnr
end

---Clear stored input method state
---@param bufnr? integer Specific buffer to clear, or nil to clear all
function M.clear(bufnr)
	if bufnr then
		local target = normalize_bufnr(bufnr)
		M.per_buffer[target] = nil
		return
	end

	M.per_buffer = {}
	M.current_im = nil
end

---Get all stored input method state
---@return { per_buffer: table<integer, string> }
function M.get()
	return {
		per_buffer = vim.deepcopy(M.per_buffer),
	}
end

---Set input method for specific buffer
---@param bufnr integer Buffer number to set
---@param im string Input method identifier
function M.set(bufnr, im)
	if bufnr and im then
		local target = normalize_bufnr(bufnr)
		M.per_buffer[target] = im
	end
end

return M
