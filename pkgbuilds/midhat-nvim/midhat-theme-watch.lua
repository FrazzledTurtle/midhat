return {
	{
		name = "midhat-theme-watch",
		dir = vim.fn.stdpath("config"),
		lazy = false,
		priority = 1000,
		config = function()
			local uv = vim.uv or vim.loop
			local dir = vim.fn.expand("~/.local/state/midhat/current")
			if vim.fn.isdirectory(dir) == 0 then
				return
			end

			local timer = uv.new_timer()
			local watcher = uv.new_fs_event()
			watcher:start(dir, {}, function(err, name)
				if err or name ~= "theme.name" then
					return
				end
				timer:stop()
				timer:start(300, 0, vim.schedule_wrap(function()
					vim.api.nvim_exec_autocmds("User", { pattern = "LazyReload" })
				end))
			end)
		end,
	},
}
