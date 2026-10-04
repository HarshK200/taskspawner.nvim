<img width="1280" height="720" alt="2026-10-0417-28-30-ezgif com-optimize(1)" src="https://github.com/user-attachments/assets/ae4ec5ad-10ee-46c4-ac7e-d50348a58714" />

# taskspawner.nvim

A lightweight, single-file Neovim plugin that runs the tasks defined in your project's `.vscode/tasks.json` inside terminal buffers, with a Telescope picker and a clickable tab bar for switching between running tasks.

## Features

- Pick a task from `.vscode/tasks.json` with [Telescope](https://github.com/nvim-telescope/telescope.nvim)
- Each task runs in its own terminal buffer, so multiple tasks can run at the same time
- Clickable winbar with one tab per active task
- Re-run the previously selected task with a single command
- Per-task custom shell (`executable` and `args`)
- Per-task focus control through `presentation.focus`
- Toggle the terminal split open and closed without losing task buffers
- Single file, no configuration options, lazy-load friendly

## Requirements

- Neovim **0.11+** (0.12+ recommended)
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
return {
	"HarshK200/taskspawner.nvim",
	-- lazy load on key press
	keys = { "<M-t>" },
	-- lazy load on commands
	cmd = { "TasksToggle", "Spawn", "SpawnPrevious" },
	dependencies = {
		"nvim-telescope/telescope.nvim",
	},
	config = function()
		require("taskspawner").setup()

		-- keymaps setup
		vim.keymap.set("n", "<M-t>", "<cmd>SpawnPrevious<cr>")
	end,
}
```

`setup()` takes no options. It registers the user commands and an autocommand that removes closed task buffers from the tab bar. Keymaps are up to you.

## Usage

1. Create a `.vscode/tasks.json` file in your project (see [`.vscode/tasks.json`](#vscodetasksjson) below) and open Neovim in the project root. The file is read from Neovim's current working directory.
2. Run `:Spawn` and choose a task in the Telescope picker.
3. The task runs in a vertical split terminal. Run `:Spawn` again to start another task; it opens in a new buffer and gets its own tab in the winbar.
4. Click a tab in the winbar to switch between tasks.
5. Run `:TasksToggle` to hide or show the terminal split.
6. Run `:SpawnPrevious` to re-run the last task you picked.

## Commands

| Command          | Description                                                                                          |
| ---------------- | ---------------------------------------------------------------------------------------------------- |
| `:Spawn`         | Opens a Telescope picker listing every task in `.vscode/tasks.json` and runs the selected one.       |
| `:SpawnPrevious` | Re-runs the task last selected with `:Spawn`. Reloads `tasks.json` and looks the task up by `label`. |
| `:TasksToggle`   | Closes the terminal split if open; otherwise reopens it with the existing task buffers.              |

Notes:

- `:SpawnPrevious` only knows about tasks picked with `:Spawn` in the current Neovim session. If none has been picked, it shows a warning.
- If the previous task's `label` no longer exists in `tasks.json`, an error is shown.
- Running the same task more than once creates a separate buffer and tab each time.
- `:TasksToggle` shows a warning if there are no task buffers to show.

## `.vscode/tasks.json`

Tasks are read from `.vscode/tasks.json` in the current working directory each time you run `:Spawn` or `:SpawnPrevious`, so edits take effect immediately.

### Example

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "build",
      "command": "make build",
      "presentation": {
        "focus": false
      }
    },
    {
      "label": "build-and-run",
      "command": "./build.sh && ./out/app",
      "options": {
        "shell": {
          "executable": "sh",
          "args": ["-c"]
        }
      },
      "presentation": {
        "focus": true
      }
    }
  ]
}
```

### Supported fields

| Field                      | Type       | Description                                                                           |
| -------------------------- | ---------- | ------------------------------------------------------------------------------------- |
| `version`                  | string     | Schema version (e.g. `"2.0.0"`).                                                      |
| `tasks`                    | array      | List of tasks.                                                                        |
| `tasks[].label`            | string     | Name shown in the picker and on the winbar tab.                                       |
| `tasks[].command`          | string     | Command to run.                                                                       |
| `options.shell.executable` | string     | Shell used to run the command (optional).                                             |
| `options.shell.args`       | string[]   | Arguments passed to the shell before the command (optional).                          |
| `presentation.focus`       | boolean    | Whether the terminal window keeps focus after the task starts.                        |

Include a `presentation` object with `focus` in every task. The plugin reads it unconditionally when a task starts.

### Custom shell

If `options.shell` is set, the plugin builds the command as:

```
<executable> <args...> <command>
```

For the `build-and-run` task above that is `sh -c "./build.sh && ./out/app"`. This is useful for running shell syntax such as `&&` under a specific shell, for example `sh.exe` on Windows.

If `options.shell` is omitted, `command` is passed directly to Neovim's default shell handling.

Tasks run with Neovim's current working directory as their `cwd`.

### Focus behavior

- `"focus": true`: the cursor stays in the task's terminal window.
- `"focus": false`: the cursor returns to the window you were in when the task was started.

## Task switching and terminal management

- The terminal opens as a vertical split about 40% of the editor width (columns / 2.5). Where it appears follows your `'splitright'` setting.
- All tasks share one terminal window. Each task has its own terminal buffer and a tab in the winbar, and the active tab is highlighted.
- Click a tab to switch tasks. You can also call `require("taskspawner").switch_task(index)` yourself, where `index` is the 1-based tab position.
- `:TasksToggle` closes only the window. Buffers and running jobs stay alive, and reopening shows the first task's buffer.
- When a task buffer is wiped (for example `:bwipeout`), it is removed from the tab bar automatically.

## Limitations

This plugin supports only a small subset of the VS Code task schema:

- `version`
- `tasks`
- `label`
- `command`
- `options.shell.executable`
- `options.shell.args`
- `presentation.focus`

Other VS Code task features are not supported and are ignored. This includes `type`, `group`, `dependsOn`, `problemMatcher`, `args`, `options.cwd`, `options.env`, input variables and platform-specific overrides.

Other things to be aware of:

- Telescope is required. If it is not installed, `:Spawn` shows an error.
- Only `.vscode/tasks.json` in the current working directory is used.
- `:SpawnPrevious` history is not kept between Neovim sessions.

## License

MIT, see [LICENSE](LICENSE).
