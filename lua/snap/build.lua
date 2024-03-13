M = {}

local spinner_frames = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" } -- spinners
local hasNvimNotify, _ = pcall(require, "notify")
local title = hasNvimNotify and "[Snap] Installing silicon using cargo..." or "[Snap]"
local notif_data = { spinner = 1, done = false, title = title }
local notify_opts = {}

local function update_spinner(notif_data) -- update spinner helper function to defer
	if hasNvimNotify and not notif_data.done and notif_data.spinner ~= nil then
		if notif_data.notification ~= nil then
			local new_spinner = (notif_data.spinner + 1) % #spinner_frames
			local ok, notification = pcall(function()
				return vim.notify(nil, nil, {
					hide_from_history = true,
					icon = spinner_frames[new_spinner],
					replace = notif_data.notification,
					title = notif_data.title,
				})
			end)

			if ok then
				notif_data.notification = notification
				notif_data.spinner = new_spinner
			end
		end

		vim.defer_fn(function()
			update_spinner(notif_data)
		end, 100)
	end
end

---@param data string|nil
local function handle_command_stream(error, data)
	if data == nil then
		return
	end
	vim.schedule(function()
		if vim.tbl_isempty(notif_data) then
			return
		end
		notify_opts = { title = title, replace = notif_data.notification }
		notif_data.notification = vim.notify(string.gsub(data, "%s+$", "") .. "...", 2, notify_opts)
	end)
end

local function buildCallback(result)
	if result.code ~= 0 and not vim.tbl_isempty(notif_data) then
		notif_data.notification = vim.notify(
			"Failed to build silicon. Exit code: " .. result.code,
			4,
			{ icon = "🞮", replace = notif_data.notification, timeout = 3000, title = "[Snap Build]" }
		)
		notif_data.done = true
		return
	end
	if not vim.tbl_isempty(notif_data) then
		notif_data.notification = vim.notify(
			"Silicon installed successfully. Restart NeoVim for changes to take effect.",
			2,
			{ icon = "", replace = notif_data.notification, timeout = 3000, title = "[Snap Build]" }
		)
		notif_data.done = true
	end
end

local function build()
	if vim.fn.executable("cargo") ~= 1 then
		error("[Snap] `cargo` not found in $PATH")
	end

	if vim.fn.executable("silicon") == 1 then
		vim.notify("[Snap] silicon already installed. Skipping build.", 2)
		return
	end

	notify_opts = {
		title = title,
		icon = spinner_frames[1],
		timeout = false,
	}
	notif_data.notification = vim.notify( -- notify with percentage and message
		"Starting build process...",
		2,
		notify_opts
	)

	if hasNvimNotify then
		update_spinner(notif_data)
	end

	vim.system({ "cargo", "install", "silicon" }, {

		stderr = handle_command_stream,
		stdout = handle_command_stream,
	}, function(result)
		vim.schedule(function()
			buildCallback(result)
		end)
	end)
end

function M.build()
	vim.schedule(build)
end

return M
