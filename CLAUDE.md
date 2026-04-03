# Godot Kodama — Project Instructions

## Project Type
3D parallax 2D sprite metroidvania game built in Godot 4.6.1, inspired by Hollow Knight's movement and physics feel.

## Engine
- **Godot 4.6.1** at `C:\Users\Admin\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.1-stable_win64.exe`
- Use the **godot MCP** for launching the editor, running scenes, and capturing debug output.

## Skills Active in This Project
All skills in `.claude/skills/` are always active:

- **hollow-knight-movement** — CharacterBody2D physics: coyote time, jump buffer, variable jump, dash, wall slide/jump, nail pogo
- **parallax-2d-sprites** — Layered 2D sprite depth system with ParallaxBackground and optional SubViewport 3D approach
- **godot-scene-architecture** — Scene tree layout, autoloads, EventBus signals, state machines, room system, save/load
- **godot-metroidvania** — Ability gating, enemy AI, combat feel (hit stop, invincibility frames), checkpoints, soul/geo systems
- **godot-gdscript** — GDScript 2.0 typed syntax, signals, resources, coroutines, physics layer conventions

## Conventions
- Always use **typed GDScript** — `var x: float`, `func foo(bar: int) -> void`
- Use **StringName** (`&"idle"`) for animation names and state machine keys
- Physics go in `_physics_process`, visuals/UI in `_process`
- Use **EventBus autoload** for cross-node communication — never direct node references across scenes
- Collision layers: 1=World, 2=Player, 3=Enemies, 4=Hazards, 5=Hitboxes, 6=Interactables
- Pixel art: `Nearest` texture filtering, base resolution `320×180` scaled up

## MCP Usage
Use the `godot` MCP server to:
- Launch the Godot editor to inspect scenes
- Run the project and capture debug output
- Execute GDScript snippets for testing
