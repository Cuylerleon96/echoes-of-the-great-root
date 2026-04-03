---
name: godot-gdscript
description: GDScript 2.0 (Godot 4) patterns, typed variables, signals, resources, coroutines, and common pitfalls when building games. Reference for syntax and idioms.
---

# GDScript 2.0 — Godot 4 Reference

## Typed Variables (always use types)
```gdscript
var speed: float = 200.0
var health: int = 5
var name: String = "Kodama"
var position: Vector2 = Vector2.ZERO
var is_dead: bool = false
var items: Array[String] = []
var node_ref: CharacterBody2D  # typed node reference
```

## Signals
```gdscript
# Declaration
signal jumped
signal took_damage(amount: int)
signal room_changed(from: String, to: String)

# Emit
jumped.emit()
took_damage.emit(2)

# Connect in code
other_node.jumped.connect(_on_player_jumped)
other_node.took_damage.connect(func(amt): print("damage: ", amt))  # lambda

# Connect in _ready
func _ready() -> void:
    $Area2D.body_entered.connect(_on_body_entered)
```

## StringName for performance (use & prefix)
```gdscript
# Use StringName for dictionary keys and animation names
_sm.transition_to(&"idle")
$AnimationPlayer.play(&"run")
if state == &"attack":
    pass
```

## Resources
```gdscript
# Define a resource
class_name EnemyData
extends Resource

@export var max_health: int = 3
@export var move_speed: float = 80.0
@export var damage: int = 1
@export var sprite: Texture2D

# Use it
@export var data: EnemyData
func _ready() -> void:
    health = data.max_health
```

## Coroutines / Await
```gdscript
# Wait for signal
await EventBus.room_transition_finished

# Wait for time
await get_tree().create_timer(0.5).timeout

# Wait for animation
$AnimationPlayer.play("death")
await $AnimationPlayer.animation_finished

# Sequence with await
func die() -> void:
    _state_machine.transition_to(&"dead")
    $AnimationPlayer.play(&"death")
    await $AnimationPlayer.animation_finished
    EventBus.player_died.emit()
    queue_free()
```

## Groups
```gdscript
# In Inspector → Node → Groups, OR:
func _ready() -> void:
    add_to_group("player")
    add_to_group("damageable")

# Check membership
if body.is_in_group("player"):
    pass

# Call on all group members
get_tree().call_group("enemies", "freeze")
```

## Autoload access
```gdscript
# Autoloads are global singletons
GameManager.load_room("room_002", "spawn_left")
EventBus.player_died.emit()
SaveSystem.save()
AbilityRegistry.unlock(AbilityRegistry.Ability.DASH)
```

## Scene instantiation
```gdscript
const EnemyScene = preload("res://characters/enemies/crawler/crawler.tscn")

func spawn_enemy(pos: Vector2) -> void:
    var enemy = EnemyScene.instantiate()
    enemy.global_position = pos
    $Entities.add_child(enemy)
```

## Tween (replaces AnimationPlayer for code-driven animation)
```gdscript
func flash_white() -> void:
    var tween = create_tween()
    tween.tween_property($Sprite2D, "modulate", Color.WHITE, 0.05)
    tween.tween_property($Sprite2D, "modulate", Color(1,1,1,0), 0.05)
    tween.tween_property($Sprite2D, "modulate", Color.WHITE, 0.05)

func slide_ui(target_pos: Vector2) -> void:
    var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
    tween.tween_property(self, "position", target_pos, 0.3)
```

## Physics Layers (project.godot)
```ini
; Assign names to avoid magic numbers
[layer_names]
2d_physics/layer_1="World"
2d_physics/layer_2="Player"
2d_physics/layer_3="Enemies"
2d_physics/layer_4="Hazards"
2d_physics/layer_5="Hitboxes"
2d_physics/layer_6="Interactables"
```

## _process vs _physics_process
- `_physics_process(delta)` — movement, velocity, physics queries — runs at fixed rate (60 FPS default)
- `_process(delta)` — animation, UI, non-physics updates — runs every render frame

**Always do movement in `_physics_process`. Never mix.**

## Common Pitfalls
- `@onready var x = $Node` — use `@onready` to get nodes safely after scene is ready
- Never call `queue_free()` inside `_physics_process` if iterating — use a flag and free in `_process`
- `get_node()` returns null if path wrong — use `get_node_or_null()` for optional nodes
- `Area2D` signal `body_entered` only fires when `monitoring = true`
- `CharacterBody2D.move_and_slide()` uses `velocity` property, not a return value (Godot 4 change)
- Delta is in seconds — multiply forces by delta, NOT velocities that are already per-second

## Project Settings to set immediately
```
Display > Window > Viewport Width/Height: 320x180 (or 1920x1080 for HD)
Display > Window > Stretch Mode: canvas_items
Display > Window > Stretch Aspect: keep
Rendering > Textures > Default Texture Filter: Nearest (pixel art)
Physics > 2D > Default Gravity: 980
Input Devices > Pointing > Emulate Touch From Mouse: true (for testing)
```

## AnimationTree for blended animations
```
AnimationTree
├─ AnimationNodeStateMachine
│   ├─ idle
│   ├─ run
│   ├─ jump_rise
│   ├─ jump_fall
│   ├─ dash
│   ├─ attack_l / attack_r / attack_u / attack_d
│   ├─ hurt
│   └─ death
```
Control via:
```gdscript
$AnimationTree.set("parameters/conditions/is_running", true)
$AnimationTree["parameters/playback"].travel("attack_down")
```
