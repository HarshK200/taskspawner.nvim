---@class ShellOptions
---@field executable string
---@field args string[]|nil

---@class Options
---@field shell ShellOptions

---@class PresentationOptions
---@field focus boolean|nil

---@class Task
---@field label string
---@field command string
---@field options Options|nil
---@field presentation PresentationOptions|nil

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

	---@type integer
	active_task_idx = nil,
}

--------------------------------------------------------------------
--                      INTERNAL FUNCTIONS
--------------------------------------------------------------------

local function refresh_winbar()
	if not vim.api.nvim_win_is_valid(M.terminal_win) then
		return
	end

	local tabs = {}

	for idx, task in ipairs(M.active_tasks) do
		local highlight = "TabLine"
		if idx == M.active_task_idx then
			highlight = "TabLineSel"
		end

		-- NOTE(harsh): %T is for end clickable area,
		-- %#TabLineSel# is for tab line selected highlight group start
		-- %* is for reset highlight group
		table.insert(
			tabs,
			string.format(
				"%%#%s#%%%d@v:lua.require'taskspawner'.switch_task@ %s %%T%%*",
				highlight,
				idx,
				task.task_label
			)
		)
	end

	vim.wo[M.terminal_win].winbar = table.concat(tabs, "  ")
end

-- Executes the task
---@param task Task
local function execute_task(task)
	-- orignal window id, so we can switch back, if focus is false
	local origin_win = vim.api.nvim_get_current_win()

	---@type ActiveTask
	local active_task = {
		task_label = task.label,
		buffer_id = 0,
		job_id = 0,
	}

	-- open a split window on the right size if it doesn't exist. Otherwise,
	-- set the existing window as current
	local width = math.floor(vim.o.columns / 2.5)
	if not M.terminal_win or not vim.api.nvim_win_is_valid(M.terminal_win) then
		vim.api.nvim_exec2(string.format("%svsplit", width), {})
		M.terminal_win = vim.api.nvim_get_current_win()
	else
		vim.api.nvim_set_current_win(M.terminal_win)
	end

	-- create a new buffer for the task and set it for the current window
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
	M.active_task_idx = #M.active_tasks -- lenght of active_tasks is same as idx of last task cause lua is 1 indexed

	-- create/update winbar
	refresh_winbar()

	-- Jump back to your original window if focus is false
	local focus = task.presentation ~= nil and task.presentation.focus == true
	if not focus and vim.api.nvim_win_is_valid(origin_win) then
		vim.api.nvim_set_current_win(origin_win)
	end
end

--------------------------------------------------------------------
--                  EXTERNALY EXPOSED FUNCTION
--------------------------------------------------------------------

-- removes any task with invalid buffer_id i.e. any stale/completed deleted task entry
function M.update_active_tasks()
	for idx = #M.active_tasks, 1, -1 do
		local task = M.active_tasks[idx]

		if not vim.api.nvim_buf_is_valid(task.buffer_id) then
			table.remove(M.active_tasks, idx)
		end
	end
end

function M.tasks_toggle()
	-- close window if terminal_win is valid i.e. opened
	if M.terminal_win and vim.api.nvim_win_is_valid(M.terminal_win) then
		vim.api.nvim_win_close(M.terminal_win, true)
		return
	end

	-- open new window if the terminal_win is invalid and there is at least one entry in M.active_tasks
	-- with a valid buffer to show
	if #M.active_tasks > 0 and vim.api.nvim_buf_is_valid(M.active_tasks[1].buffer_id) then
		local width = math.floor(vim.o.columns / 2.5)
		vim.api.nvim_exec2(string.format("%svsplit", width), {})
		M.terminal_win = vim.api.nvim_get_current_win()
		vim.api.nvim_set_current_buf(M.active_tasks[1].buffer_id)
		M.active_task_idx = 1

		-- refresh winbar since the active tasks might have been updated since last open window
		refresh_winbar()
	else
		vim.notify("TaskSpawner: no tasks to show", vim.log.levels.WARN)
		return
	end
end

---@param task_idx integer
function M.switch_task(task_idx)
	local task = M.active_tasks[task_idx]
	if not task then
		vim.notify("TaskSpawner: invalid task index recieved", vim.log.levels.ERROR)
		return
	end
	if not vim.api.nvim_buf_is_valid(task.buffer_id) then
		vim.notify(
			string.format("TaskSpawner: trying to switch to a task with invalid buffer_id: %d", task.buffer_id),
			vim.log.levels.ERROR
		)
		return
	end

	vim.api.nvim_win_set_buf(M.terminal_win, task.buffer_id)
	M.active_task_idx = task_idx
	refresh_winbar()
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

-- Deprecated: kept so existing configs don't break. Commands are now
-- registered automatically by plugin/taskspawner.lua.
function M.setup() end

return M
