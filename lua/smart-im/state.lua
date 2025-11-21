local M = {}

---@type table<string, string> Per-filetype input method state
M.per_filetype = {}

---@type string? Global input method state for untracked filetypes
M.global = nil

---@type string? Currently active input method
M.current_im = nil

---Clear stored input method state
---@param ft? string Specific filetype to clear, or nil to clear all
function M.clear(ft)
	if ft then
		M.per_filetype[ft] = nil
	else
		M.per_filetype = {}
		M.global = nil
	end
end

---Get all stored input method state
---@return table<string, string> state Copy of per-filetype state with global included
function M.get()
	local copy = vim.deepcopy(M.per_filetype)
	copy.global = M.global
	return copy
end

---Set input method for specific filetype
---@param ft string Filetype to set
---@param im string Input method identifier
function M.set(ft, im)
	if ft and im then
		M.per_filetype[ft] = im
	end
end

return M
