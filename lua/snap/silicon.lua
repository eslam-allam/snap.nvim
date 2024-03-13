local M = {}

function M.list_themes()
	local result = vim.system({ "silicon", "--list-themes" }):wait()
	if result.code ~= 0 then
		return {}
	end

	return require("snap.helpers").splitStr(result.stdout, "\n")
end

return M
