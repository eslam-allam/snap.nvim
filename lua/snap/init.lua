---@class snap.opts
---@field default_action "clipboard" | "file"
---@field hide_ln_numbers boolean
---@field no_rounded_corners boolean
---@field hide_controls boolean
---@field hide_window_title boolean
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
---@field default_path string | fun(buffer: number):string
---@field window_title string | fun(buffer: number):string

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

local M = {}

---@type snap.opts
M.opts = {
	default_action = "clipboard",
	hide_ln_numbers = false,
	no_rounded_corners = false,
	hide_controls = false,
	hide_window_title = false,
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
	default_path = function(_)
		return vim.fn.getcwd() .. "/" .. uuid()
	end,
	window_title = "%:t",
}

M.themes = {}

local helpers = require("snap.helpers")
local silicon = require("snap.silicon")
local build_command = "SnapBuild"
local opts_configured = false

local function mergeOpts(opts)
	if opts == nil then
		return true
	end
	local mergedOpts = vim.tbl_deep_extend("force", M.opts, opts)

	if mergedOpts.theme:match("^tmTheme://") then
		local themeFile = vim.fn.expand(mergedOpts.theme:sub(11))
		if not themeFile:match("%.tmTheme$") then
			vim.notify("[Snap] Invalid theme file: " .. themeFile .. ". Must be a .tmTheme file", 4)
			return false
		end
		if vim.fn.filereadable(themeFile) ~= 1 then
			vim.notify("[Snap] Could not find theme file: " .. themeFile, 4)
			return false
		end
		mergedOpts.theme = themeFile
	elseif not helpers.contains(M.themes, mergedOpts.theme) then
		vim.notify(
			"[Snap] Invalid theme: " .. mergedOpts.theme .. ". Must be one of:\n" .. table.concat(M.themes, ",\n"),
			4,
			{ timeout = 5000 }
		)
		return false
	end

	if not (type(mergedOpts.default_path) == "string" or type(mergedOpts.default_path) == "function") then
		vim.notify("[Snap] Invalid default_path. Must be a function or string.", 4)
		return false
	end

	M.opts = mergedOpts
	return true
end

---@param opts snap.opts?
function M.setup(opts)
	vim.api.nvim_create_user_command(build_command, function()
		require("snap.build").build()
	end, {})

	vim.api.nvim_create_user_command("Snap", M.silicon, { nargs = "*" })

	if vim.fn.executable("silicon") ~= 1 then
		vim.notify("[Snap] silicon is not installed. Run " .. build_command .. " to install it.", 4)
		return
	end
	M.themes = silicon.list_themes()
	opts_configured = mergeOpts(opts)
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
		insert_all(command, "-o", helpers.quote(opts.file_path))
	end
	insert_all(command, "--language", helpers.quote(tostring(vim.bo.filetype)))
	if M.opts.hide_ln_numbers then
		table.insert(command, "--no-line-number")
	end

	if M.opts.no_rounded_corners then
		table.insert(command, "--no-round-corner")
	end

	if M.opts.hide_controls then
		table.insert(command, "--no-window-controls")
	end

	if not M.opts.hide_window_title then
		table.insert(command, "--window-title")
		if type(M.opts.window_title) == "function" then
			table.insert(command, helpers.quote(M.opts.window_title(vim.api.nvim_get_current_buf())))
		else
			assert(type(M.opts.window_title) == "string", "Window title must be a function or string.")
			table.insert(command, helpers.quote(vim.fn.expand(M.opts.window_title)))
		end
	end

	insert_all(command, "--theme", helpers.quote(M.opts.theme))
	insert_all(command, "--line-offset", M.opts.line_offset)
	insert_all(command, "--line-pad", M.opts.line_pad)
	insert_all(command, "--pad-horiz", M.opts.pad_h)
	insert_all(command, "--pad-vert", M.opts.pad_v)
	insert_all(command, "--shadow-blur-radius", M.opts.shadow_blur_radius)
	insert_all(command, "--shadow-color", helpers.quote(M.opts.shadow_color))
	insert_all(command, "--shadow-offset-x", M.opts.shadow_offset_x)
	insert_all(command, "--shadow-offset-y", M.opts.shadow_offset_y)
	insert_all(command, "--tab-width", M.opts.tab_width)
	insert_all(command, "--background", helpers.quote(M.opts.background_colour))

	if M.opts.background_image ~= nil then
		insert_all(command, "--background-image", helpers.quote(M.opts.background_image))
	end

	return table.concat(command, " "), action
end

function M.silicon(options)
	print(M.opts.theme)
	if vim.fn.executable("silicon") ~= 1 then
		local result = vim.fn.input({
			prompt = "[Snap] silicon is not installed. Would you like to install it. (y/n): ",
			cancel_return = "n",
		})
		if not helpers.contains({ "y", "n" }, result) then
			vim.notify("[Snap] invalid response", 4)
		end
		if result == "y" then
			vim.cmd("SnapBuild")
		end
		return
	end

	if not opts_configured then
		vim.notify_once("[Snap] Snap is not configured. Using default options.", vim.log.levels.WARN)
	end

	if not helpers.contains({ "v", "vs", "V", "Vs", "CTRL+V", "CTRL+Vs" }, vim.fn.mode()) then
		vim.notify("[Snap] not in visual mode!", 4)
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
	local default_path = ""

	if type(M.opts.default_path) == "function" then
		default_path = M.opts.default_path(vim.api.nvim_get_current_buf())
	else
		assert(type(M.opts.default_path) == "string", "Default path must be a function or string.")
		default_path = vim.fn.expand(M.opts.default_path)
	end

	local defaults = {
		type = M.opts.default_action,
		file_path = default_path,
	}

	if opts == nil then
		opts = {}
	end

	opts = vim.tbl_deep_extend("keep", opts, defaults)

	opts.file_path = helpers.appendExtension(helpers.expandAndAbsolute(opts.file_path), ".png")

	local command, action = buildCommand(opts)

	vim.fn.system("echo " .. vim.fn.shellescape(highlightedText) .. " | " .. command)

	if vim.v.shell_error == 0 then
		vim.notify("[Snap] Succesfully " .. action, 2)
	else
		vim.notify("[Snap] Failed to generate image.", 4)
	end
end

return M
