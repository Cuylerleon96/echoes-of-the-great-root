---
name: godot-scene-architecture
description: Godot 4 scene tree architecture for a metroidvania — node composition patterns, autoloads, signals-based event bus, save/load system, room management, and state machines.
---

# Godot 4 Scene Architecture for Metroidvania

## Top-Level Scene Tree

```
Main (Node)
├─ World (Node2D)
│   ├─ RoomManager (Node)          ← handles room loading/unloading
│   ├─ CurrentRoom (Node2D)        ← active room instance
│   │   ├─ TileMapLayer_BG        ← visual background tiles
│   │   ├─ TileMapLayer_Terrain   ← collidable tiles (Layer 1)
│   │   ├─ TileMapLayer_FG        ← foreground tiles
│   │   ├─ Entities (Node2D)      ← enemies, interactables spawned here
│   │   ├─ ParallaxLayers         ← per-room parallax backgrounds
│   │   └─ Hazards
│   └─ Player (CharacterBody2D)   ← persists across rooms, re-parented
├─ UI (CanvasLayer, layer=10)
│   ├─ HUD
│   ├─ PauseMenu
│   └─ TransitionOverlay          ← fade in/out between rooms
└─ Camera2D                       ← child of Player or World depending on approach
```

## Autoloads (Project Settings → Autoload)

```
GameManager     res://autoloads/game_manager.gd      ← global state, current room
EventBus        res://autoloads/event_bus.gd          ← signal relay
SaveSystem      res://autoloads/save_system.gd        ← save/load
AudioManager    res://autoloads/audio_manager.gd      ← music/sfx pooling
InputManager    res://autoloads/input_manager.gd      ← rebindable inputs
```

## EventBus (Decoupled Signals)

```gdscript
# autoloads/event_bus.gd
extends Node

# Player
signal player_died
signal player_healed(amount: int)
signal player_soul_changed(current: int, max_val: int)
signal player_geo_changed(amount: int)

# Combat
signal enemy_died(enemy: Node2D, position: Vector2)
signal hit_landed(target: Node2D, damage: int, position: Vector2)

# World
signal room_transition_started(next_room: String)
signal room_transition_finished
signal checkpoint_activated(checkpoint_id: String)
signal item_collected(item_id: String)

# UI
signal show_notification(text: String, duration: float)
```

Usage:
```gdscript
# Emitting
EventBus.player_died.emit()

# Connecting (in _ready)
EventBus.enemy_died.connect(_on_enemy_died)
```

## State Machine (Lightweight)

```gdscript
# state_machine.gd — reusable component
class_name StateMachine
extends Node

var current_state: StringName = &""
var states: Dictionary = {}

func add_state(name: StringName, enter: Callable, process: Callable, exit: Callable) -> void:
    states[name] = { "enter": enter, "process": process, "exit": exit }

func transition_to(new_state: StringName) -> void:
    if current_state != &"" and states.has(current_state):
        states[current_state]["exit"].call()
    current_state = new_state
    if states.has(current_state):
        states[current_state]["enter"].call()

func process(delta: float) -> void:
    if states.has(current_state):
        states[current_state]["process"].call(delta)
```

Player state example:
```gdscript
# States: idle, run, jump, fall, dash, attack, hurt, dead, wall_slide
func _ready() -> void:
    _sm = StateMachine.new()
    add_child(_sm)
    _sm.add_state(&"idle",       _idle_enter,       _idle_process,       _idle_exit)
    _sm.add_state(&"run",        _run_enter,        _run_process,        _run_exit)
    _sm.add_state(&"jump",       _jump_enter,       _jump_process,       _jump_exit)
    _sm.add_state(&"dash",       _dash_enter,       _dash_process,       _dash_exit)
    _sm.add_state(&"wall_slide", _wall_slide_enter, _wall_slide_process, _wall_slide_exit)
    _sm.add_state(&"attack",     _attack_enter,     _attack_process,     _attack_exit)
    _sm.add_state(&"hurt",       _hurt_enter,       _hurt_process,       _hurt_exit)
    _sm.transition_to(&"idle")
```

## Room System

```gdscript
# autoloads/game_manager.gd
extends Node

const ROOMS_PATH = "res://world/rooms/"
var current_room_id: String = ""

func load_room(room_id: String, spawn_point: String = "default") -> void:
    EventBus.room_transition_started.emit(room_id)
    # Transition overlay fades to black
    await get_tree().create_timer(0.3).timeout
    
    var room_scene = load(ROOMS_PATH + room_id + ".tscn")
    var world = get_tree().root.get_node("Main/World")
    
    # Remove old room
    var old_room = world.get_node_or_null("CurrentRoom")
    if old_room:
        old_room.queue_free()
    
    # Load new room
    var new_room = room_scene.instantiate()
    new_room.name = "CurrentRoom"
    world.add_child(new_room)
    
    # Move player to spawn point
    var spawn = new_room.get_node_or_null("SpawnPoints/" + spawn_point)
    if spawn:
        world.get_node("Player").global_position = spawn.global_position
    
    current_room_id = room_id
    EventBus.room_transition_finished.emit()
```

## Save System

```gdscript
# autoloads/save_system.gd
extends Node

const SAVE_PATH = "user://save_data.tres"

var data: Dictionary = {
    "room": "room_001",
    "spawn": "default",
    "health": 5,
    "max_health": 5,
    "geo": 0,
    "abilities": [],
    "visited_rooms": [],
    "defeated_enemies": [],
    "collected_items": [],
    "checkpoints": {}
}

func save() -> void:
    var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    f.store_string(JSON.stringify(data))

func load_save() -> bool:
    if not FileAccess.file_exists(SAVE_PATH):
        return false
    var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
    var result = JSON.parse_string(f.get_as_text())
    if result is Dictionary:
        data.merge(result, true)
        return true
    return false
```

## Node Composition Pattern (prefer composition over inheritance)

```
Player (CharacterBody2D)
├─ MovementComponent (Node)      ← all movement physics
├─ HealthComponent (Node)        ← HP, damage, invincibility frames
├─ CombatComponent (Node)        ← attack hitboxes, nail swings
├─ AbilityComponent (Node)       ← dash, double jump, wall climb
├─ AnimationTree (AnimationTree) ← blends animations from states
├─ Hurtbox (Area2D)              ← receives damage
├─ Sprite2D
└─ CollisionShape2D
```

Each component accesses siblings via `owner` reference:
```gdscript
# health_component.gd
func _ready() -> void:
    _player = owner  # CharacterBody2D
```

## File Structure
```
res://
├─ autoloads/
├─ characters/
│   ├─ player/
│   │   ├─ player.tscn
│   │   ├─ player.gd
│   │   ├─ movement_component.gd
│   │   ├─ health_component.gd
│   │   └─ player_frames.tres
│   └─ enemies/
│       ├─ crawler/
│       └─ flying/
├─ world/
│   ├─ rooms/
│   ├─ tilesets/
│   └─ parallax/
├─ ui/
├─ assets/
│   ├─ sprites/
│   ├─ audio/
│   └─ fonts/
└─ shaders/
```
