<img width="1280" height="720" alt="2026-10-0417-28-30-ezgif com-optimize(1)" src="https://github.com/user-attachments/assets/ae4ec5ad-10ee-46c4-ac7e-d50348a58714" />

# taskspawner.nvim

A lightweight, single-file Neovim plugin that runs the tasks in your project's `.vscode/tasks.json` inside terminal buffers, with a Telescope picker and a clickable winbar for switching between running tasks.

## Features

- Pick a task with [Telescope](https://github.com/nvim-telescope/telescope.nvim)
- Each task runs in its own terminal buffer, so several can run at once
- Clickable winbar with one tab per active task
- Re-run the previous task with one command
- Per-task custom shell and focus control
- Toggle the terminal split without losing task buffers
- No `setup()` and no options. Install it and the commands are available

## Requirements

- Neovim **0.11+** (0.12+ recommended)
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
return {
	"HarshK200/taskspawner.nvim",
	dependencies = { "nvim-telescope/telescope.nvim" },
	cmd = { "Spawn", "SpawnPrevious", "TasksToggle" },
	keys = {
		{ "<M-t>", "<cmd>SpawnPrevious<cr>", desc = "Spawn previous task" },
	},
	config = function()
		-- keymaps setup
		vim.keymap.set("n", "<M-t>", "<cmd>SpawnPrevious<cr>")
	end,
}
```
`Note: require("taskspawner").setup() is not longer needed`

With the built-in `vim.pack`:

```lua
vim.pack.add({
	"https://github.com/nvim-telescope/telescope.nvim",
	"https://github.com/HarshK200/taskspawner.nvim",
})
```

> **Upgrading from v1.0.0:** `require("taskspawner").setup()` is no longer needed. It still works as a no-op, so existing configs won't break, but you can remove it.

## Usage

Create a `.vscode/tasks.json` in your project root and open Neovim from there. Run `:Spawn`, pick a task, and it runs in a vertical split terminal. Click a winbar tab to switch between tasks.

| Command          | Description                                                                |
| ---------------- | -------------------------------------------------------------------------- |
| `:Spawn`         | Pick a task from `tasks.json` and run it in a new terminal buffer          |
| `:SpawnPrevious` | Re-run the last task picked with `:Spawn` (reloads `tasks.json`)           |
| `:TasksToggle`   | Close the terminal split, or reopen it with the existing task buffers      |

- The previous task is remembered only for the current Neovim session.
- Running the same task again opens a new buffer and tab.
- Closing the split with `:TasksToggle` keeps running jobs alive. Wiped task buffers are removed from the winbar automatically.
- You can switch tasks from Lua with `require("taskspawner").switch_task(index)` (1-based).

## `.vscode/tasks.json`

`tasks.json` is read from Neovim's current working directory each time you run a command, so edits apply immediately.

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "build",
      "command": "make build",
      "presentation": { "focus": false }
    },
    {
      "label": "build-and-run",
      "command": "./build.sh && ./out/app",
      "options": {
        "shell": { "executable": "sh", "args": ["-c"] }
      },
      "presentation": { "focus": true }
    }
  ]
}
```

| Field                      | Description                                                              |
| -------------------------- | ------------------------------------------------------------------------ |
| `version`                  | Schema version, e.g. `"2.0.0"`                                           |
| `tasks[].label`            | Name shown in the picker and on the winbar tab                           |
| `tasks[].command`          | Command to run                                                           |
| `options.shell.executable` | Shell used to run the command (optional)                                 |
| `options.shell.args`       | Arguments passed to the shell before the command (optional)              |
| `presentation.focus`       | `true` keeps the cursor in the terminal, `false` returns to your window  |

**Custom shell:** with `options.shell` set, the plugin runs `<executable> <args...> <command>`, for example `sh -c "./build.sh && ./out/app"`. This is handy for shell syntax like `&&`, or for `sh.exe` on Windows. Without it, the command goes to Neovim's default shell handling. Tasks run in Neovim's current working directory.

## Limitations

Only these parts of the VS Code task schema are supported: `version`, `tasks`, `label`, `command`, `options.shell.executable`, `options.shell.args` and `presentation.focus`. Everything else (`type`, `group`, `dependsOn`, `problemMatcher`, `args`, `options.cwd`, `options.env`, input variables, platform overrides) is ignored.

Telescope is required, and only `.vscode/tasks.json` in the current working directory is used.

## License

MIT, see [LICENSE](LICENSE).
