local PlenaryPath = require("snap.path")
local random = math.random

local M = {}

function M.getHighlightedLines(range, line1, line2)
	if range ~= 0 then
		return vim.fn.getline(line1, line2), line1, line2
	end
	local vstart = vim.fn.getpos("'<")

	local vend = vim.fn.getpos("'>")

	local line_start = vstart[2]
	local line_end = vend[2]

	-- or use api.nvim_buf_get_lines
	return vim.fn.getline(line_start, line_end), line_start, line_end
end

function M.absolutePath(fname)
	return PlenaryPath:new(fname):absolute()
end

function M.uuid()
	math.randomseed(tonumber(tostring(os.time()):reverse():sub(1, 9)))

	local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
	return (
		string.gsub(template, "[xy]", function(c)
			local v = (c == "x") and random(0, 0xf) or random(8, 0xb)
			return string.format("%x", v)
		end)
	)
end

function M.splitStr(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	local t = {}
	for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
		table.insert(t, str)
	end
	return t
end

function M.contains(array, value)
	for _, v in ipairs(array) do
		if v == value then
			return true
		end
	end
	return false
end

function M.ReadFile(file)
	local f = assert(io.open(file, "rb"))
	local content = f:read("*all")
	f:close()
	return content
end

---@param condition boolean
---@param message string
---@param opts table?
function M.assert(condition, message, opts)
	if not condition then
		vim.notify(message, 4, opts)
		return false
	end
	return true
end

function M.copyFileToClipboard(file_path)
	local os_name = vim.fn.has("linux") == 1 and "Linux"
		or vim.fn.has("macunix") == 1 and "Darwin"
		or vim.fn.has("win32") == 1 and "Windows"
		or "unknown"

	if os_name == "Linux" or os_name == "Darwin" then
		local cmd = nil
		local display_server = vim.fn.getenv("XDG_SESSION_TYPE")
		if os_name == "Linux" then
			if display_server == "wayland" then
				cmd = { "wl-copy", "--type", "image/png" }
			else
				cmd = { "xclip", "-selection", "clipboard", "-t", "image/png" }
			end
		else
			cmd = { "pbcopy" }
		end
		local result = vim.system(cmd, { stdin = M.ReadFile(file_path) }):wait()
		if result.code ~= 0 then
			return false
		end
	elseif os_name == "Windows" then
		local cmd = { "file2clip", file_path }
		local result = vim.system(cmd):wait()
		if result.code ~= 0 then
			return false
		end
	else
		print("Unsupported operating system.")
		return false
	end
	return true
end

function M.copyFile(source_path, destination_path)
	local source_file = io.open(source_path, "rb")
	if not source_file then
		print("Error: Unable to open source file.")
		return false
	end

	local destination_file = io.open(destination_path, "wb")
	if not destination_file then
		source_file:close()
		print("Error: Unable to open destination file.")
		return false
	end

	local chunk_size = 4096
	while true do
		local chunk = source_file:read(chunk_size)
		if not chunk then
			break
		end
		destination_file:write(chunk)
	end

	source_file:close()
	destination_file:close()

	return true
end
return M
