---@class snap.opts
---@field default_action "clipboard" | "file"
---@field hide_ln_numbers boolean
---@field no_rounded_corners boolean
---@field hide_controls boolean
---@field background_colour string
---@field background_image string?
---@field line_offset number
---@field line_pad number
---@field pad_h number
---@field pad_v number
---@field shadow_blur_radius number
---@field shadow_color string
---@field shadow_offset_x number
---@field shadow_offset_y number
---@field tab_width number
---@field theme string
---@field default_path string

---@class snap.do.opts
---@field type "clipboard" | "file"
---@field file_path string

local function uuid()
	math.randomseed(tonumber(tostring(os.time()):reverse():sub(1, 9)))

	local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
	local random = math.random
	return (
		string.gsub(template, "[xy]", function(c)
			local v = (c == "x") and random(0, 0xf) or random(8, 0xb)
			return string.format("%x", v)
		end)
	)
end

M = {}

---@type snap.opts
M.opts = {
	default_action = "clipboard",
	hide_ln_numbers = false,
	no_rounded_corners = false,
	hide_controls = false,
	background_colour = "#aaaaff",
	background_image = nil,
	line_offset = 1,
	line_pad = 2,
	pad_h = 80,
	pad_v = 100,
	shadow_blur_radius = 0,
	shadow_color = "#555555",
	shadow_offset_x = 0,
	shadow_offset_y = 0,
	tab_width = 4,
	theme = "Dracula",
	default_path = vim.fn.getcwd() .. "/" .. uuid(),
}

local helpers = require("snap.helpers")

---@param opts snap.opts?
function M.setup(opts)
	if opts ~= nil then
		M.opts = vim.tbl_deep_extend("force", M.opts, opts)
	end
	vim.api.nvim_create_user_command("Silicon", M.silicon, { nargs = "*" })
end

local function insert_all(list, ...)
	for i = 1, select("#", ...) do
    local value = select(i, ...)
		table.insert(list, value)
	end
end

---builds the command string
---@param opts snap.do.opts
---@return string
---@return string
local function buildCommand(opts)
	local command = { "silicon" }

	local action = ""

	if opts.type == "clipboard" then
		action = "copied image to clipboard"
		table.insert(command, "--to-clipboard")
	end

	if opts.type == "file" then
		action = "saved image to " .. opts.file_path
		insert_all(command, "-o", opts.file_path)
	end
	insert_all(command, "--language", tostring(vim.bo.filetype))
	if M.opts.hide_ln_numbers then
		table.insert(command, "--no-line-number")
	end

	if M.opts.no_rounded_corners then
		table.insert(command, "--no-round-corner")
	end

	if M.opts.hide_controls then
		table.insert(command, "--no-window-controls")
	end

	insert_all(command, "--theme", M.opts.theme)
	insert_all(command, "--line-offset", M.opts.line_offset)
	insert_all(command, "--line-pad", M.opts.line_pad)
	insert_all(command, "--pad-horiz", M.opts.pad_h)
	insert_all(command, "--pad-vert", M.opts.pad_v)
	insert_all(command, "--shadow-blur-radius", M.opts.shadow_blur_radius)
	insert_all(command, "--shadow-color", M.opts.shadow_color)
	insert_all(command, "--shadow-offset-x", M.opts.shadow_offset_x)
	insert_all(command, "--shadow-offset-y", M.opts.shadow_offset_y)
	insert_all(command, "--tab-width", M.opts.tab_width)
	insert_all(command, "--background", M.opts.background_colour)

	if M.opts.background_image ~= nil then
		insert_all(command, "--background-image", M.opts.background_image)
	end

	return table.concat(command, " "), action
end

function M.silicon(options)
	if not helpers.contains({ "v", "vs", "V", "Vs", "CTRL+V", "CTRL+Vs" }, vim.fn.mode()) then
		vim.notify("[Silicon] not in visual mode!", 4)
		return
	end

	local keys = vim.api.nvim_replace_termcodes("<ESC>", true, false, true)
	vim.api.nvim_feedkeys(keys, "x", false)
	local unsplit_opts = options.fargs

	local opts = {}
	for _, val in pairs(unsplit_opts) do
		local split_table = helpers.splitStr(val, "=")
		opts = vim.tbl_extend("keep", opts, { [split_table[1]] = split_table[2] })
	end

	local highlightedText = helpers.appendTableEntries(helpers.getHighlightedLines(), "\n")

	local defaults = {
		type = M.opts.default_action,
		file_path = M.opts.default_path,
	}

	if opts == nil then
		opts = {}
	end

	opts = vim.tbl_deep_extend("keep", opts, defaults)

	opts.file_path = helpers.appendExtension(helpers.expandAndAbsolute(opts.file_path), ".png")

	local command, action = buildCommand(opts)

	vim.fn.system("echo " .. vim.fn.shellescape(highlightedText) .. " | " .. command)

	if vim.v.shell_error == 0 then
		vim.notify("[Silicon] Succesfully " .. action, 2)
	else
		vim.notify("[Silicon] Failed to generate image.", 4)
	end
end

return M