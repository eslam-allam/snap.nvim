local M = {}

local spinner_frames = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" } -- spinners
local hasNvimNotify, notify = pcall(require, "notify")
local title = hasNvimNotify and "[Snap] Installing silicon using cargo..." or "[Snap]"
local notif_data = { spinner = 1, done = false, title = title }

local function notify_output(data, level, opts)
	if not hasNvimNotify then
		vim.notify(data, level, opts)
		return
	end
	vim.schedule_wrap(function()
		if not notif_data.notification then
			notif_data.notification = notify(
				data,
				level,
				vim.tbl_extend("keep", opts or {}, {
					title = title,
					timeout = false,
				})
			)
			return
		end
		notif_data.notification = notify.notify(
			data,
			level,
			vim.tbl_extend("keep", opts or {}, {
				hide_from_history = true,
				replace = notif_data.notification,
			})
		)
	end)()
end

local function update_spinner() -- update spinner helper function to defer
	if hasNvimNotify and not notif_data.done and notif_data.spinner ~= nil then
		if notif_data.notification ~= nil then
			local new_spinner = (notif_data.spinner + 1) % #spinner_frames
			notify_output(nil, nil, {
				icon = spinner_frames[new_spinner],
			})
			notif_data.spinner = new_spinner
		end

		vim.defer_fn(function()
			update_spinner()
		end, 100)
	end
end

---@param data string|nil
local function handle_command_stream(error, data)
	if data == nil then
		return
	end
	notify_output(string.gsub(data, "%s+$", "") .. "...")
end

local function buildCallback(result)
	if result.code ~= 0 and not vim.tbl_isempty(notif_data) then
		notify_output(
			"Failed to build silicon. Exit code: " .. result.code,
			4,
			{ icon = "🞮", replace = notif_data.notification, timeout = 3000, title = "[Snap Build]" }
		)
		notif_data.done = true
		return
	end
	if not vim.tbl_isempty(notif_data) then
		notify_output(
			"Silicon installed successfully. Restart NeoVim to apply your config.",
			2,
			{ icon = "", replace = notif_data.notification, timeout = 3000, title = "[Snap Build]" }
		)
		notif_data.done = true
	end
end

function M.build()
	if vim.fn.executable("cargo") ~= 1 then
		error("[Snap] `cargo` not found in $PATH")
	end

	if vim.fn.executable("silicon") == 1 then
		vim.notify("[Snap] silicon already installed. Skipping build.", 2)
		return
	end

	notify_output("Starting build process...", 2, { icon = spinner_frames[1] })

	if hasNvimNotify then
		update_spinner()
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

return M
