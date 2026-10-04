---@class ShellOptions
---@field executable string
---@field args string[]|nil

---@class Options
---@field shell ShellOptions

---@class PresentationOptions
---@field focus boolean

---@class Task
---@field label string
---@field command string
---@field options Options|nil
---@field presentation PresentationOptions

---@class Tasks
---@field version string
---@field tasks Task[]

---@class ActiveTask
---@field task_label string
---@field buffer_id integer
---@field job_id integer

local M = {
	---@type Task|nil
	previous_task = nil,

	---@type ActiveTask[]
	active_tasks = {},

	---@type integer
	terminal_win = nil,
}

---Executes the task
---@param task Task
local function execute_task(task)
	-- orignal window id, so we can switch back, if focus is false
	local origin_win = vim.api.nvim_get_current_win()

	-- create a new buffer for jobstart to work in
	---@type ActiveTask
	local active_task = {
		task_label = task.label,
		buffer_id = 0,
		job_id = 0,
	}

	-- open a split window on the right size if it doesn't exist. Otherwise,
	-- set the existing window as current
	-- TODO(harsh): add a winbar
	local width = math.floor(vim.o.columns / 2.5)
	if not M.terminal_win or not vim.api.nvim_win_is_valid(M.terminal_win) then
		vim.api.nvim_exec2(string.format("%svsplit", width), {})
		M.terminal_win = vim.api.nvim_get_current_win()
	else
		vim.api.nvim_set_current_win(M.terminal_win)
	end

	-- create a buffer for the task and set it for the current window
	active_task.buffer_id = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_current_buf(active_task.buffer_id)

	-- Execute the terminal command with provided shell
	if task.options and task.options.shell then
		-- add the custom shell path to executable command list
		local cmd = { task.options.shell.executable }

		-- add the shell arguments to the command list
		if task.options.shell.args then
			vim.list_extend(cmd, task.options.shell.args)
		end

		-- add the tasks build/run command to the cmd list
		table.insert(cmd, task.command)

		active_task.job_id = vim.fn.jobstart(cmd, {
			term = true,
			cwd = vim.fn.getcwd(),
			width = width,
		})
	else
		-- just use the nvim's default call to run a command
		active_task.job_id = vim.fn.jobstart(task.command, {
			term = true,
			cwd = vim.fn.getcwd(),
			width = width,
		})
	end

	-- Makes sure the cursor is at the bottom so terminal output scrolls with it
	vim.api.nvim_win_set_cursor(M.terminal_win, {
		vim.api.nvim_buf_line_count(active_task.buffer_id),
		0,
	})

	-- insert the task into the active_tasks list
	table.insert(M.active_tasks, active_task)

	-- Jump back to your original window if focus is false
	if vim.api.nvim_win_is_valid(origin_win) and task.presentation.focus == false then
		vim.api.nvim_set_current_win(origin_win)
	end
end

function M.spawn_task()
	-- Check if Telescope is installed at runtime
	local has_telescope, _ = pcall(require, "telescope")
	if not has_telescope then
		vim.notify("TaskSpawner: telescope is required for this plugin", vim.log.levels.ERROR)
		return
	end
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local config = require("telescope.config")
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")

	-- get .vscode/tasks.json absolute filepath
	local json_file = vim.fs.joinpath(vim.fn.getcwd(), ".vscode", "tasks.json")

	-- read .vscode/tasks.json file
	if vim.fn.filereadable(json_file) == 0 then
		vim.notify("ERROR: .vscode/tasks.json not found", vim.log.levels.ERROR)
		return
	end
	local file = io.open(json_file, "r")
	if not file then
		vim.notify("ERROR: Failed to read .vscode/tasks.json", vim.log.levels.ERROR)
		return
	end
	local content = file:read("*a")
	file:close()

	-- decode json file
	---@type boolean, Tasks
	local success, tasks_file = pcall(vim.json.decode, content)
	if not success or type(tasks_file) ~= "table" then
		vim.notify("ERROR: Failed to parse .vscode/tasks.json", vim.log.levels.ERROR)
		return
	end

	-- open telescope for picking
	pickers
		.new({
			layout_strategy = "horizontal",
			sorting_strategy = "ascending",
			previewer = false,
			layout_config = {
				height = 0.4,
				width = 0.4,
				anchor = "N", -- keeps the whole telescope window at the top
				horizontal = {
					prompt_position = "top", -- Keeps the text prompt at the top of that window
				},
			},
		}, {
			prompt_title = "Select Task to Spawn",
			finder = finders.new_table({
				results = tasks_file["tasks"], -- following the .vscode\tasks.json schema
				---@param task Task
				entry_maker = function(task)
					return {
						value = task,
						display = task.label,
						ordinal = task.label .. " " .. (task.command or ""), -- the actual choice text shown
					}
				end,
			}),

			sorter = config.values.generic_sorter({}),
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					if selection then
						M.previous_task = selection.value
						execute_task(selection.value)
					else
						vim.notify("WARN: no entry selected", vim.log.levels.WARN)
					end
				end)
				return true
			end,
		})
		:find()
end

function M.spawn_previous_task()
	if not M.previous_task then
		vim.notify("WARN: no previous command", vim.log.levels.WARN)
		return
	end

	-- get tasks.json filepath
	local json_file = vim.fs.joinpath(vim.fn.getcwd(), ".vscode", "tasks.json")

	-- read tasks.json file
	if vim.fn.filereadable(json_file) == 0 then
		vim.notify("ERROR: .vscode/tasks.json not found", vim.log.levels.ERROR)
		return
	end
	local file = io.open(json_file, "r")
	if not file then
		vim.notify("ERROR: Failed to read .vscode/tasks.json", vim.log.levels.ERROR)
		return
	end
	local content = file:read("*a")
	file:close()

	-- decode json file
	---@type boolean, Tasks
	local success, tasks_file = pcall(vim.json.decode, content)
	if not success or type(tasks_file) ~= "table" then
		vim.notify("ERROR: Failed to parse .vscode/tasks.json", vim.log.levels.ERROR)
		return
	end

	local task
	for _, t in ipairs(tasks_file["tasks"]) do
		if t.label == M.previous_task.label then
			task = t
		end
	end
	if not task then
		vim.notify("Error: previous task " .. M.previous_task.label .. " is not in tasks.json", vim.log.levels.ERROR)
		return
	end

	execute_task(task)
end

function M.setup()
	-- create user commands
	vim.api.nvim_create_user_command("Spawn", M.spawn_task, {})
	vim.api.nvim_create_user_command("SpawnPrevious", M.spawn_previous_task, {})
end

return M
