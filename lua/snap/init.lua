---@class snap.watermark
---@field text string
---@field font string
---@field font_color string
---@field font_size number
---@field position "North" | "South" | "East" | "West" | "NorthEast" | "NorthWest" | "SouthEast" | "SouthWest" | "Center" | "Tile"
---@field opacity number

---@class snap.opts
---@field default_action "clipboard" | "file"
---@field hide_ln_numbers boolean
---@field no_rounded_corners boolean
---@field hide_controls boolean
---@field hide_window_title boolean
---@field background_colour string
---@field background_image string?
---@field line_offset boolean
---@field line_pad number
---@field pad_h number
---@field pad_v number
---@field shadow_blur_radius number
---@field shadow_color string
---@field shadow_offset_x number
---@field shadow_offset_y number
---@field tab_width number
---@field theme string
---@field default_path string | fun(buffer: number):string If string then it is path to a directory. If function then it must return the path including the file name. Both paths may be relative and may use modifiers to be expanded by |expand()|.
---@field window_title string | fun(buffer: number):string
---@field watermark snap.watermark?

---@class snap.do.opts
---@field type "clipboard" | "file"
---@field file_path string
---@field line_offset number

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
  line_offset = false,
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
		return vim.fn.getcwd() .. "/" .. uuid() .. ".png"
	end,
	window_title = "%:t",
	watermark = nil,
}

M.themes = {}
M.watermark_positions = { "North", "South", "East", "West", "NorthEast", "NorthWest", "SouthEast", "SouthWest", "Center", "Tile" }

local helpers = require("snap.helpers")
local silicon = require("snap.silicon")
local assert = function(condition, message, opts)
	return helpers.assert(condition, "[Snap] " .. message, opts)
end
local build_command = "SnapBuild"
local opts_configured = false

local function verifyWaterMarkOpts(watermark)
	if watermark == nil then
		return true
	end
	if not assert(watermark.text, "watermark text cannot be empty.") then
		return false
	end
	if not assert(watermark.font, "watermark font cannot be empty.") then
		return false
	end
	if not assert(watermark.font_color, "watermark font_color cannot be empty.") then
		return false
	end
	if
		not assert(
			watermark.font_size ~= nil and watermark.font_size > 0,
			"watermark font_size must be a non negative number."
		)
	then
		return false
	end
	if
		not assert(
			watermark.position and helpers.contains(M.watermark_positions, watermark.position),
			"invalid watermark position. Must be one of:\n" .. table.concat(M.watermark_positions, ",\n")
		)
	then
		return false
	end
	if
		not assert(
			watermark.opacity ~= nil and watermark.opacity >= 0 and watermark.opacity <= 1,
			"watermark opacity must be a number between 0 and 1."
		)
	then
		return false
	end
	return true
end

---@param opts snap.opts
local function mergeOpts(opts)
	if opts == nil then
		return true
	end
	local mergedOpts = vim.tbl_deep_extend("force", M.opts, opts)

	-- default_action
	if not assert(helpers.contains({ "clipboard", "file" }, mergedOpts.default_action), "Invalid default_action") then
		return false
	end

	-- background_colour
	if not assert(mergedOpts.background_colour:match("^#%x%x%x%x%x%x$"), "Invalid background_colour") then
		return false
	end

	-- background_image
	if
		mergedOpts.background_image ~= nil
		and not assert(vim.fn.filereadable(mergedOpts.background_image), "Background image does not exist")
	then
		return false
	end

	-- hide_controls
	if not assert(type(mergedOpts.hide_controls) == "boolean", "hide_controls must be a boolean") then
		return false
	end

	-- hide_ln_numbers
	if not assert(type(mergedOpts.hide_ln_numbers) == "boolean", "hide_ln_numbers must be a boolean") then
		return false
	end

	-- hide_window_title
	if not assert(type(mergedOpts.hide_window_title) == "boolean", "hide_window_title must be a boolean") then
		return false
	end

	-- line_offset
	if not assert(type(mergedOpts.line_offset) == "boolean", "line_offset must be a boolean") then
		return false
	end

	-- line_pad
	if not assert(mergedOpts.line_pad >= 0, "line_pad must be a non-negative number") then
		return false
	end

	-- no_rounded_corners
	if not assert(type(mergedOpts.no_rounded_corners) == "boolean", "no_rounded_corners must be a boolean") then
		return false
	end

	-- pad_h
	if not assert(mergedOpts.pad_h >= 0, "pad_h must be a non-negative number") then
		return false
	end

	-- pad_v
	if not assert(mergedOpts.pad_v >= 0, "pad_v must be a non-negative number") then
		return false
	end

	-- shadow_blur_radius
	if not assert(mergedOpts.shadow_blur_radius >= 0, "shadow_blur_radius must be a non-negative number") then
		return false
	end

	-- shadow_color
	if not assert(mergedOpts.shadow_color:match("^#%x%x%x%x%x%x$"), "Invalid shadow_color") then
		return false
	end

	-- shadow_offset_x
	if not assert(mergedOpts.shadow_offset_x >= 0, "shadow_offset_x must be a non-negative number") then
		return false
	end

	-- shadow_offset_y
	if not assert(mergedOpts.shadow_offset_y >= 0, "shadow_offset_y must be a non-negative number") then
		return false
	end

	-- tab_width
	if not assert(mergedOpts.tab_width >= 0, "tab_width must be a non-negative number") then
		return false
	end

	-- window_title
	if
		not assert(
			type(mergedOpts.window_title) == "string" or type(mergedOpts.window_title) == "function",
			"Invalid window_title. Must be a string or function."
		)
	then
		return false
	end
  
	-- Theme
	if mergedOpts.theme:match("^tmTheme://") then
		local themeFile = vim.fn.expand(mergedOpts.theme:sub(11))
		if
			not assert(
				themeFile:match("%.tmTheme$"),
				"Invalid theme file: " .. themeFile .. ". Must be a .tmTheme file"
			)
		then
			return false
		end
		if not assert(vim.fn.filereadable(themeFile) == 1, "Could not find theme file: " .. themeFile) then
			return false
		end
		mergedOpts.theme = themeFile
	elseif
		not assert(
			helpers.contains(M.themes, mergedOpts.theme),
			"Invalid theme: " .. mergedOpts.theme .. ". Must be one of:\n" .. table.concat(M.themes, ",\n"),
			{ timeout = 5000 }
		)
	then
		return false
	end

	-- default_path
	if
		not assert(
			(type(mergedOpts.default_path) == "string" or type(mergedOpts.default_path) == "function"),
			"Invalid default_path. Must be a function or string."
		)
	then
		return false
	end

	-- watermark
	if not verifyWaterMarkOpts(mergedOpts.watermark) then
		return false
	end

	M.opts = mergedOpts
	return true
end

local function insert_all(list, ...)
	for i = 1, select("#", ...) do
		local value = select(i, ...)
		table.insert(list, value)
	end
end

---builds the command string
---@param opts snap.do.opts
---@return table
---@return string
---@return string?
local function buildCommand(opts, linestart)
	local command = { "silicon" }

	local action = ""

	if opts.type == "clipboard" then
		action = "copied image to clipboard"
		if M.opts.watermark == nil then
			table.insert(command, "--to-clipboard")
		end
	end

	if opts.type == "file" then
		action = "saved image to " .. opts.file_path
		if M.opts.watermark == nil then
			insert_all(command, "-o", opts.file_path)
		end
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

	if not M.opts.hide_window_title then
		table.insert(command, "--window-title")
		if type(M.opts.window_title) == "function" then
			table.insert(command, M.opts.window_title(vim.api.nvim_get_current_buf()))
		else
			assert(type(M.opts.window_title) == "string", "Window title must be a function or string.")
			table.insert(command, vim.fn.expand(M.opts.window_title))
		end
	end

	insert_all(command, "--theme", M.opts.theme)
	insert_all(command, "--line-offset", M.opts.line_offset and linestart or 1)
	insert_all(command, "--line-pad", M.opts.line_pad)
	insert_all(command, "--pad-horiz", M.opts.pad_h)
	insert_all(command, "--pad-vert", M.opts.pad_v)
	insert_all(command, "--shadow-blur-radius", M.opts.shadow_blur_radius)
	insert_all(command, "--shadow-color", M.opts.shadow_color)
	insert_all(command, "--shadow-offset-x", M.opts.shadow_offset_x)
	insert_all(command, "--shadow-offset-y", M.opts.shadow_offset_y)
	insert_all(command, "--tab-width", M.opts.tab_width)

	if M.opts.background_image == nil then
		insert_all(command, "--background", M.opts.background_colour)
	end

	if M.opts.background_image ~= nil then
		insert_all(command, "--background-image", vim.fn.expand(M.opts.background_image))
	end
	if M.opts.watermark ~= nil then
		local tmpfile = vim.fn.tempname() .. opts.file_path:match("%.[a-zA-Z]+$")
		insert_all(command, "-o", tmpfile)
		return command, action, tmpfile
	end

	return command, action
end

local function pointSizeToRes(point_size)
	return tostring(point_size * 12) .. "x" .. tostring(point_size * 4)
end

local function tiledWaterMark()
	return vim.system({
		"magick",
		"convert",
		"-size",
		pointSizeToRes(M.opts.watermark.font_size),
		"xc:none",
		"-font",
		M.opts.watermark.font,
		"-pointsize",
		tostring(M.opts.watermark.font_size),
		"-fill",
		M.opts.watermark.font_color,
		"-gravity",
		"NorthWest",
		"-draw",
		"text 10,10 '" .. M.opts.watermark.text .. "'",
		"-gravity",
		"SouthEast",
		"-draw",
		"text 5,15 '" .. M.opts.watermark.text .. "'",
		"miff:-",
	}):wait()
end

local function standardWaterMark()
	return vim.system({
		"magick",
		"convert",
		"-size",
		pointSizeToRes(M.opts.watermark.font_size),
		"xc:none",
		"-font",
		M.opts.watermark.font,
		"-pointsize",
		tostring(M.opts.watermark.font_size),
		"-fill",
		M.opts.watermark.font_color,
		"-gravity",
		"Center",
		"-draw",
		"text 0,0 '" .. M.opts.watermark.text .. "'",
		"miff:-",
	}):wait()
end

local function applyWaterMark(opts, tmpfile)
	if not vim.fn.executable("magick") == 1 then
		vim.notify("[Snap] magick is not installed. Please install it to use watermarks.", 4)
		return false
	end
	local watermarkStampResult = M.opts.watermark.position == "Tile" and tiledWaterMark() or standardWaterMark()
	if not assert(watermarkStampResult.code == 0, "Failed to generate watermark image") then
		vim.fn.delete(tmpfile)
		return false
	end
	local waterMarkCompositeOpts = {
		"magick",
		"composite",
		"-dissolve",
		tostring(M.opts.watermark.opacity * 100) .. "%",
		"-",
		tmpfile,
		tmpfile,
	}

	if M.opts.watermark.position == "Tile" then
		table.insert(waterMarkCompositeOpts, 3, "-tile")
	else
		table.insert(waterMarkCompositeOpts, 3, "-gravity")
		table.insert(waterMarkCompositeOpts, 4, M.opts.watermark.position)
	end

	local addWatermark = vim.system(waterMarkCompositeOpts, { stdin = watermarkStampResult.stdout }):wait()
	if not assert(addWatermark.code == 0, "Failed to composite watermark") then
		vim.fn.delete(tmpfile)
		return false
	end
	if opts.type == "clipboard" then
		if not assert(helpers.copyFileToClipboard(tmpfile), "Failed to copy image to clipboard") then
			vim.fn.delete(tmpfile)
			return false
		end
	end
	if opts.type == "file" then
		if not assert(helpers.copyFile(tmpfile, opts.file_path), "Failed to generate image") then
			vim.fn.delete(tmpfile)
			return false
		end
	end
	vim.fn.delete(tmpfile)
	return true
end

local function takeSnap(options)
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

	if options.range == 0 and not helpers.contains({ "v", "vs", "V", "Vs", "CTRL+V", "CTRL+Vs" }, vim.fn.mode()) then
		vim.notify("[Snap] not in visual mode!", 4)
		return
	end

	local keys = vim.api.nvim_replace_termcodes("<ESC>", true, false, true)
	vim.api.nvim_feedkeys(keys, "x", false)

	local opts = {}
	for option, val in options.args:gmatch("([^= ]+)=([^= ]+)") do
		opts = vim.tbl_extend("keep", opts, { [option] = val })
	end
  
  local lines, linestart, _ = helpers.getHighlightedLines(options.range, options.line1, options.line2)
	local highlightedText = table.concat(lines, "\n")
	local default_path = ""

	if type(M.opts.default_path) == "function" then
		default_path = M.opts.default_path(vim.api.nvim_get_current_buf())
	else
		assert(type(M.opts.default_path) == "string", "Default path must be a function or string.")
		default_path = vim.fn.expand(M.opts.default_path):gsub("[\\/]+$", "") .. "/" .. helpers.uuid() .. ".png"
	end

	local defaults = {
		type = M.opts.default_action,
		file_path = default_path,
	}

	if opts == nil then
		opts = {}
	end

	if opts.file_path ~= nil then
		opts.file_path = vim.fn.expand(opts.file_path)
	end

	opts = vim.tbl_deep_extend("keep", opts, defaults)

	opts.file_path = helpers.absolutePath(opts.file_path)
	vim.fn.mkdir(opts.file_path:gsub("[^/\\]+$", ""), "p")

	local command, action, tmpfile = buildCommand(opts, linestart)

	local result = vim.system(command, { stdin = highlightedText }):wait()

	if result.code == 0 and result.stderr == "" then -- Silicon doesn't always return a non-zero exit code on error
		if tmpfile ~= nil then
			if not applyWaterMark(opts, tmpfile) then
				return
			end
		end
		vim.notify("[Snap] Succesfully " .. action, 2)
	else
		vim.notify("[Snap] Failed to generate image.\n" .. result.stderr, 4)
	end
end

---@param opts snap.opts?
function M.setup(opts)
	vim.api.nvim_create_user_command(build_command, function()
		require("snap.build").build()
	end, {})

	vim.api.nvim_create_user_command("Snap", takeSnap, { nargs = "*", range = true })

	if vim.fn.executable("silicon") ~= 1 then
		vim.notify("[Snap] silicon is not installed. Run " .. build_command .. " to install it.", 4)
		return
	end
	M.themes = silicon.list_themes()
	opts_configured = mergeOpts(opts)
end

return M
