# Echoes of the Great Root — Project Instructions

## Game
2.5D metroidvania in Godot 4.6.1. Player is Echo, a Kodama spirit saving the Mother Tree across three eras (Past / Present / Future). Inspired by Hollow Knight's movement feel.

## Engine
- **Godot 4.6.1** at `C:\Users\Admin\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.1-stable_win64.exe`
- Use the **godot MCP** for launching the editor, running scenes, and capturing debug output.
- GitHub repo: `https://github.com/Cuylerleon96/echoes-of-the-great-root`

## Session Workflow
**Do this at the start of every session:**
1. Read memory files in `.claude/projects/.../memory/` for project context
2. Run `git log --oneline -10` to see what was last worked on
3. Ask the user where they want to pick up, or suggest the next logical step
4. At the end of every session: commit all changes and push to GitHub

**Do this at the end of every session:**
1. Commit everything with a clear message describing what changed
2. Push to `origin master`
3. Update memory if anything significant was decided or changed

## Current State (update this each session)
- Full movement: walk, jump (coyote + buffer + variable height), double jump, dash (X/B), wall jump, wall slide, fast fall
- Green capsule placeholder; `AnimatedSprite3D` wired with 8 animation slots — ready for sprites
- Two enemy types: Pouncer (alert → pounce → recover → return) and Flyer (idle → chase → stunned/fall-death)
- Combat: take_damage with i-frames + knockback; stun ability (E key / X button, 2.2u range, 1.5s cooldown)
- HUD: 3 hearts + stun cooldown bar (`ui/hud.gd`); camera: lookahead + soft deadzone (`main.gd`)
- Respawn: fall → last platform touched (−1 heart); death → origin + enemy reset
- Touch controls wired (`ui/touch_controls.gd`), auto-hide on desktop
- **Not yet:** audio, rooms, checkpoints, ability gating, enemy HP

## Architecture
- **Node3D root** + **Camera3D (orthographic, size=10)** — all gameplay on XY plane, Z=0
- **CharacterBody3D** for Echo (NOT CharacterBody2D — we're in a 3D scene)
- **Sprite3D / AnimatedSprite3D** for visuals at different Z depths for parallax
- Manual parallax script needed (orthographic camera has no natural depth parallax)
- World scale: 1 unit ≈ 72px at camera.size=10, 720p viewport

## Key Files
- `main.tscn` — main scene (currently the test stage)
- `main.gd` — camera follow + fall respawn
- `characters/echo/echo.gd` — player root, drives animations, catches dash input
- `characters/echo/movement_component.gd` — all physics (self-contained, no autoload deps)

## Movement Tuning (current values)
- `move_speed = 5.2` — top speed
- `dash_speed = 14.0`, `dash_duration = 0.20` — ~2.8 units distance
- `jump_height = 1.7`, peak `0.38s`, fall `0.28s`
- All abilities ON: `has_double_jump`, `has_dash`, `has_wall_jump`
- Dash key: **X** (Shift was unreliable as a modifier key in Godot)

## Keybindings
| Action | Keyboard |
|---|---|
| Move | A/D or Arrow keys |
| Jump | Space |
| Dash | X |
| Fast fall | S / Down |

## Sprite Import (ready for tonight)
- Drop PNGs into `res://assets/sprites/echo/`
- Select Echo → AnimatedSprite3D → open SpriteFrames in Inspector
- Animations pre-wired: `idle`, `run`, `jump_rise`, `jump_fall`, `wall_slide`, `dash`, `hurt`, `death`
- Placeholder mesh hides itself automatically once any animation has frames loaded

## GDScript Conventions
- Always typed: `var x: float`, `func foo(bar: int) -> void`
- StringName for animation/state keys: `&"idle"`
- Physics in `_physics_process`, visuals in `_process`
- `get_parent()` not `owner` to reference parent node from a component
- Collision layers: 1=World, 2=Player, 3=Enemies, 4=Hazards, 5=Hitboxes, 6=Interactables

## Skills Active
All skills in `.claude/skills/` load automatically:
- **hollow-knight-movement** — HK-style physics reference
- **parallax-2d-sprites** — 2.5D depth layering
- **godot-scene-architecture** — scene tree, autoloads, EventBus, room system
- **godot-metroidvania** — ability gating, combat, checkpoints
- **godot-gdscript** — GDScript 2.0 syntax and idioms
