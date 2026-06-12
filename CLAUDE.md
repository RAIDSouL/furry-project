# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

"Furry Project" is a **Godot 4.6** game project. It is currently a fresh skeleton: only `project.godot` and the default `icon.svg` exist — there are no scenes (`.tscn`), scripts (`.gd`/`.cs`), shaders, or a configured main scene yet. Expect to scaffold these from scratch.

## Godot MCP Pro (AI ↔ editor bridge)

This project has **Godot MCP Pro v1.14.1** installed — a live bridge between Claude and the running Godot editor (163 tools: scene/node/script editing, 3D, physics, runtime game inspection, input simulation, testing).

- **Addon** (WebSocket client, runs in editor): `addons/godot_mcp/` — enable via *Project → Project Settings → Plugins → Godot MCP Pro*. A green dot in the "MCP Pro" bottom panel means connected.
- **Node.js server** (lives outside the project): `C:\Users\Thund\godot-mcp-pro\server\` — launched automatically by Claude via `.mcp.json`. Rebuild/update with `node build/setup.js install`; health-check with `node build/setup.js doctor`.
- **Config**: `.mcp.json` (server registration), `.claude/skills.md` (tool usage guide for Claude).
- **To use**: open the project in Godot with the plugin enabled, then ask Claude to act on the editor. Every change goes through Godot's UndoRedo, so Ctrl+Z works. The server auto-scans ports 6505–6509 — do not set a fixed `GODOT_MCP_PORT`.

## Engine configuration

The settings in `project.godot` constrain how things must be built:

- **Renderer: Forward+** (`config/features` includes `"Forward Plus"`). This is the desktop-class rendering backend — not Mobile or Compatibility. Materials, lighting, and shaders should target Forward+.
- **3D physics: Jolt Physics** (`3d/physics_engine="Jolt Physics"`), not the legacy Godot Physics. Use Jolt-compatible bodies/shapes for 3D work.
- **Rendering driver (Windows): Direct3D 12** (`rendering_device/driver.windows="d3d12"`), not Vulkan.

The combination of Forward+, Jolt, and a 3D physics engine signals this is intended as a **3D project**.

## Common commands

There is no build system, package manager, or test framework — Godot is the toolchain. Run everything through the Godot 4.6 editor/executable (`godot`/`Godot_v4.6...exe`):

```sh
# Open the project in the editor
godot --editor --path .

# Run the project (requires a main scene to be set first; none is configured yet)
godot --path .

# Run a specific scene headlessly / directly
godot --path . res://path/to/scene.tscn

# Import assets without opening the GUI (useful after adding resources)
godot --headless --editor --quit --path .
```

Godot has no separate lint/build step: scripts are checked when the project is opened or run, and the project is exported via the editor's Project > Export (or `godot --export-release "<preset>" <output>` once an export preset exists).

## Conventions

- Line endings are **LF** for all files (`.gitattributes`: `* text=auto eol=lf`), charset UTF-8 (`.editorconfig`).
- `.godot/` is generated cache and is gitignored — never edit or commit it. The same applies to `/android/`.
- `*.import` files (e.g. `icon.svg.import`) are Godot-generated import metadata and should be committed alongside their source assets.
