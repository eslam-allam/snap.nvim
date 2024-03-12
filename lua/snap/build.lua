M = {}

function M.build()
	if vim.fn.executable("cargo") ~= 1 then
		error("[Snap] `cargo` not found in $PATH")
	end

	if vim.fn.executable("silicon") == 1 then
		vim.notify("[Snap] silicon already installed. Skipping build.", 2)
		return
	end

	local spinner_frames = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" } -- spinners

	local hasNvimNotify, _ = pcall(require, "notify")

	local function update_spinner(notif_data) -- update spinner helper function to defer
		if hasNvimNotify and not notif_data.done and notif_data.spinner ~= nil then
			local new_spinner = (notif_data.spinner + 1) % #spinner_frames
			notif_data.spinner = new_spinner

			notif_data.notification = vim.notify(nil, nil, {
				hide_from_history = true,
				icon = spinner_frames[new_spinner],
				replace = notif_data.notification,
				title = notif_data.title,
			})

			vim.defer_fn(function()
				update_spinner(notif_data)
			end, 100)
		end
	end

	local title = hasNvimNotify and "[Snap] Installing silicon using cargo..." or "[Snap]"
	local notif_data = { spinner = 1, done = false, title = title }
	local notify_opts = {}

	local function buildCallback(code)
		if code ~= 0 and not vim.tbl_isempty(notif_data) then
			notif_data.notification = vim.notify(
				"Failed to build silicon. Exit code: " .. code,
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
	update_spinner(notif_data)

	vim.fn.jobstart({ "cargo", "install", "silicon" }, {

		on_stderr = function(_, data, _)
			vim.schedule(function()
				if vim.tbl_isempty(notif_data) then
					return
				end
				notify_opts = { title = title, replace = notif_data.notification }
				notif_data.notification = vim.notify(table.concat(data, " ") .. "...", 2, notify_opts)
			end)
		end,
		on_stdout = function(_, data, _)
			vim.schedule(function()
				if vim.tbl_isempty(notif_data) then
					return
				end
				notify_opts = { title = title, replace = notif_data.notification }
				notif_data.notification = vim.notify(table.concat(data, " ") .. "...", 2, notify_opts)
			end)
		end,
		on_exit = function(_, code, _)
			vim.schedule(function()
				buildCallback(code)
			end)
		end,
	})
end

return M
