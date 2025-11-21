local M = {}

M.per_filetype = {}
M.current_im = nil

function M.clear(ft)
	if ft then
		M.per_filetype[ft] = nil
	else
		M.per_filetype = {}
	end
end

function M.get()
	return vim.deepcopy(M.per_filetype)
end

function M.set(ft, im)
	if ft and im then
		M.per_filetype[ft] = im
	end
end

return M
