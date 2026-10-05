# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0](https://github.com/HarshK200/taskspawner.nvim/compare/v1.0.0...v1.1.0) (2026-10-05)

### Added

- `presentation` and `presentation.focus` are now optional. `focus` defaults to `false`.
- Commands (`:Spawn`, `:SpawnPrevious`, `:TasksToggle`) and the cleanup autocommand are now registered automatically from `plugin/taskspawner.lua`. No `setup()` call is needed after installing.

### Changed

- The plugin's main module is now loaded only when a command is first used, instead of at startup.

### Deprecated

- `require("taskspawner").setup()` is now a no-op kept for backwards compatibility. Existing configs that call it keep working, but the call can be removed.

## [1.0.0](https://github.com/HarshK200/taskspawner.nvim/releases/tag/v1.0.0) (2026-10-04)

### Added

- Pick a task from `.vscode/tasks.json` with Telescope using `:Spawn`.
- Run each task in its own terminal buffer, with support for multiple tasks at once.
- Clickable winbar to switch between active tasks.
- Re-run the last selected task with `:SpawnPrevious`.
- Toggle the terminal split with `:TasksToggle` while keeping task buffers.
- Custom shell per task through `options.shell.executable` and `options.shell.args`.
- Focus control per task through `presentation.focus`.
