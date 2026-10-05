-- guard so the file doesn't run twice
if vim.g.loaded_taskspawner then
	return
end
vim.g.loaded_taskspawner = true

-- register user commands
vim.api.nvim_create_user_command("TasksToggle", function()
	require("taskspawner").tasks_toggle()
end, {})
vim.api.nvim_create_user_command("Spawn", function()
	require("taskspawner").spawn_task()
end, {})
vim.api.nvim_create_user_command("SpawnPrevious", function()
	require("taskspawner").spawn_previous_task()
end, {})

-- plugin autocommands
vim.api.nvim_create_autocmd("BufWipeout", {
	callback = function()
		-- nothing to clean up if the plugin was never used
		local ts = package.loaded["taskspawner"]
		if ts then
			vim.schedule(ts.update_active_tasks)
		end
	end,
})
