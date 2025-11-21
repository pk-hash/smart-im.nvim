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
	if ft == "global" then
		M.global = nil
		M.current_im = nil
		return
	end

	if ft then
		M.per_filetype[ft] = nil
		return
	end

	M.per_filetype = {}
	M.global = nil
	M.current_im = nil
end

---Get all stored input method state
---@return { per_filetype: table<string, string>, global: string? }
function M.get()
	return {
		per_filetype = vim.deepcopy(M.per_filetype),
		global = M.global,
	}
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
