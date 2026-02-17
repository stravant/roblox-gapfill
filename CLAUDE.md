# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

GapFill is a Roblox Studio plugin which allows the user to click edges of two parts in 3d space, and
have the plugin generate geometry that "fills the gap" between those edges. The user can choose a
thickness for the generated geometry.
It outputs a `.rbxmx` plugin file built via Rojo.

## Build Commands

```bash
# Build the plugin to the plugins directory (default build task)
rojo build -p "GapFill V2.0.rbxmx"

# Run tests (*.spec.lua files in the Src folder)
# Tests can call t.screenshot("name") to capture the viewport (use Read tool to view the output)
# For UI tests: mount into ScreenGui parented to CoreGui, use ReactRoblox.act to flush rendering
python runtests.py

# Install dependencies (must fix the Luau types after installing)
wally install
rojo sourcemap default.project.json --output sourcemap.json
wally-package-types --sourcemap sourcemap.json Packages
```

Tools are managed via Aftman (`aftman.toml`): Rojo 7.6.1. Dependencies are managed via Wally (`wally.toml`).

## Architecture

Three-layer design:

1. **Functionality layer** — Scene manipulation, handle rendering, ghost previews, final placement.
   - `src/createGapFillSession.lua` — Session lifecycle: creates/updates/commits duplicated geometry, manages undo waypoints.
   - `src/doFill.lua` — Generate geometry that fills the gap between two edges.
   - `src/Dragger/` — 3D handle implementations (Move, Rotate, Scale) built on DraggerFramework.
   - `src/TestTypes.lua` — Types definition of the testing framework, spec files take in a type from here.

2. **Settings layer** — Persistent configuration that the functionality layer reads.
   - `src/Settings.lua` — Reads/writes plugin settings, exposes current configuration state.

3. **UI layer** — React components that modify settings and trigger operations.
   - `src/GapFillGui.lua` — Main settings panel (React).
   - `src/PluginGui/` — Reusable UI components (NumberInput, Vector3Input, Checkbox, ChipToggle, etc.).

**Entry point:** `loader.server.lua` creates the toolbar button and dock widget, then lazy-loads `src/main.lua` on first activation. `src/main.lua` orchestrates the three layers — it listens for selection changes, manages the active model refect session, and mounts the React UI.

## Key Conventions

- All source files use `--!strict` (Luau strict type checking) and many use `--!native` (native codegen).
- Types are defined with `export type` and collected in `src/PluginGui/Types.lua` for UI-related types.
- React components use `React.createElement` (aliased as `e`) — not JSX.
- The Signal library (`Packages.Signal`) is used for custom events throughout.
- Modules typically `return` a single function (e.g., `createGapFillSession`, `doFill`) rather than a table of exports.
- Undo/redo integrates with `ChangeHistoryService` using recording-based waypoints

## Dependencies (via Wally)

- **React / ReactRoblox / RoactCompat** — UI framework
- **DraggerFramework / DraggerSchemaCore** — 3D handle/manipulator system (authored by stravant)
- **DraggerHandler** — Simple wrapper around DraggerFramework to activate a basic dragger tool that can move selected objects.
- **Signal (GoodSignal)** — Event system
- **createSharedToolbar** — Optional toolbar combining with other plugins