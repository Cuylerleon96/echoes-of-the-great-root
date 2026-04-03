---
name: godot-metroidvania
description: Metroidvania-specific systems in Godot 4 — ability gating, map system, checkpoint/respawn, enemy AI patterns, combat feel, and world interconnection design.
---

# Metroidvania Game Systems (Godot 4)

## Ability Gating

```gdscript
# autoloads/ability_registry.gd
extends Node

enum Ability {
    DOUBLE_JUMP,
    DASH,
    WALL_JUMP,
    SUPER_DASH,
    DREAM_NAIL,
    SWIM,
    CLAW,          # wall cling
    WINGS,         # double jump equivalent
    ISMAS_TEAR,    # acid resistance
}

var unlocked: Array[Ability] = []

func unlock(ability: Ability) -> void:
    if ability not in unlocked:
        unlocked.append(ability)
        EventBus.item_collected.emit("ability_" + str(ability))

func has(ability: Ability) -> bool:
    return ability in unlocked
```

Gate usage in movement:
```gdscript
# In AbilityComponent
func can_double_jump() -> bool:
    return AbilityRegistry.has(AbilityRegistry.Ability.DOUBLE_JUMP) and _jumps_remaining > 0

func can_dash() -> bool:
    return AbilityRegistry.has(AbilityRegistry.Ability.DASH) and _dash_cooldown_timer <= 0
```

## Enemy AI — Hollow Knight Style Patterns

### Crawler (basic ground enemy)
```gdscript
# enemies/crawler/crawler.gd
extends CharacterBody2D

enum State { PATROL, ALERT, ATTACK, HURT, DEAD }
var state = State.PATROL

@export var patrol_speed: float = 60.0
@export var chase_speed: float = 110.0
@export var detect_range: float = 200.0
@export var attack_range: float = 40.0

var _direction: float = 1.0
var _player: Node2D

func _physics_process(delta: float) -> void:
    match state:
        State.PATROL:  _patrol(delta)
        State.ALERT:   _chase(delta)
        State.ATTACK:  _attack(delta)

func _patrol(delta: float) -> void:
    velocity.x = _direction * patrol_speed
    velocity.y += 980.0 * delta  # gravity
    move_and_slide()
    # Turn at edges/walls
    if is_on_wall() or _at_ledge():
        _direction *= -1.0
    # Detect player
    if _player and global_position.distance_to(_player.global_position) < detect_range:
        state = State.ALERT

func _at_ledge() -> bool:
    # Raycast downward ahead of movement direction
    var space = get_world_2d().direct_space_state
    var query = PhysicsRayQueryParameters2D.create(
        global_position + Vector2(_direction * 16, 0),
        global_position + Vector2(_direction * 16, 32)
    )
    return space.intersect_ray(query).is_empty()
```

### Hurtbox / Hitbox System
```gdscript
# components/hurtbox.gd
class_name Hurtbox
extends Area2D

signal hit_received(damage: int, knockback: Vector2)

func receive_hit(damage: int, knockback_dir: Vector2) -> void:
    hit_received.emit(damage, knockback_dir)

# components/hitbox.gd
class_name Hitbox
extends Area2D

@export var damage: int = 1
@export var knockback_force: float = 300.0

func _on_area_entered(area: Area2D) -> void:
    if area is Hurtbox:
        var dir = (area.global_position - global_position).normalized()
        area.receive_hit(damage, dir * knockback_force)
```

## Combat Feel (Hollow Knight)

```gdscript
# combat_component.gd
extends Node

@export var invincibility_duration: float = 0.8
@export var knockback_duration: float = 0.15
@export var hit_stop_duration: float = 0.06  # freeze frames on hit

var _invincible: bool = false
var _knockback_velocity: Vector2 = Vector2.ZERO

func take_damage(damage: int, knockback: Vector2) -> void:
    if _invincible:
        return
    
    # Hit stop — freeze the world briefly
    Engine.time_scale = 0.05
    await _owner.get_tree().create_timer(hit_stop_duration * 0.05).timeout
    Engine.time_scale = 1.0
    
    _health -= damage
    _knockback_velocity = knockback
    _invincible = true
    
    # Flash sprite
    _sprite.material = preload("res://materials/hit_flash.tres")
    await _owner.get_tree().create_timer(0.1).timeout
    _sprite.material = null
    
    await _owner.get_tree().create_timer(invincibility_duration).timeout
    _invincible = false
    
    if _health <= 0:
        EventBus.player_died.emit()
```

Hit flash shader:
```glsl
// materials/hit_flash.gdshader
shader_type canvas_item;
void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    COLOR = vec4(1.0, 1.0, 1.0, tex.a);
}
```

## Checkpoint / Bench System

```gdscript
# world/bench.gd (Hollow Knight's "bench" = save point)
extends Area2D

@export var bench_id: String = "bench_001"
var _activated: bool = false

func _on_body_entered(body: Node2D) -> void:
    if not body.is_in_group("player"):
        return
    if Input.is_action_just_pressed("interact"):
        _activate()

func _activate() -> void:
    if _activated:
        return
    _activated = true
    # Heal player
    EventBus.player_healed.emit(9999)
    # Save
    SaveSystem.data["room"] = GameManager.current_room_id
    SaveSystem.data["spawn"] = bench_id
    SaveSystem.save()
    EventBus.checkpoint_activated.emit(bench_id)
    # Play sit animation, show menu etc.
```

## Map System

```gdscript
# ui/map.gd
extends Control

# Each room has a MapData resource
class_name MapData
extends Resource

@export var room_id: String
@export var map_position: Vector2i  # grid position on map
@export var connections: Array[String]  # connected room IDs
@export var map_icon: Texture2D

# Track visited rooms
func mark_visited(room_id: String) -> void:
    if room_id not in SaveSystem.data["visited_rooms"]:
        SaveSystem.data["visited_rooms"].append(room_id)
```

## Soul / Mana System (Hollow Knight's SOUL)

```gdscript
# components/soul_component.gd
extends Node

@export var max_soul: int = 99
var current_soul: int = 0

const SOUL_PER_HIT: int = 11
const FOCUS_COST: int = 33  # heal cost

func gain_soul(amount: int = SOUL_PER_HIT) -> void:
    current_soul = min(current_soul + amount, max_soul)
    EventBus.player_soul_changed.emit(current_soul, max_soul)

func can_focus() -> bool:
    return current_soul >= FOCUS_COST

func spend_soul(amount: int) -> void:
    current_soul = max(0, current_soul - amount)
    EventBus.player_soul_changed.emit(current_soul, max_soul)
```

## Room Transition Triggers

```gdscript
# world/door.gd
extends Area2D

@export var target_room: String = "room_002"
@export var target_spawn: String = "entrance_left"
@export var transition_direction: Vector2 = Vector2.RIGHT

func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group("player"):
        # Check direction matches (avoid accidental triggers)
        if transition_direction.dot(body.velocity.normalized()) > 0.3:
            GameManager.load_room(target_room, target_spawn)
```

## Geo (Currency) System

```gdscript
# components/geo_component.gd
extends Node

var geo: int = 0 : set = _set_geo

func _set_geo(value: int) -> void:
    geo = value
    EventBus.player_geo_changed.emit(geo)
    SaveSystem.data["geo"] = geo

func add_geo(amount: int) -> void:
    geo += amount

func spend_geo(amount: int) -> bool:
    if geo < amount:
        return false
    geo -= amount
    return true
```

## Deathpenalty — Drop Shade (Hollow Knight's shade mechanic)

```gdscript
# When player dies, spawn a "shade" enemy at death location holding lost geo
# Player must defeat shade to reclaim geo
func _on_player_died() -> void:
    var shade_scene = preload("res://characters/shade/shade.tscn")
    var shade = shade_scene.instantiate()
    shade.geo_held = SaveSystem.data.get("lost_geo", 0)
    shade.global_position = SaveSystem.data.get("death_position", Vector2.ZERO)
    get_tree().root.get_node("Main/World/CurrentRoom/Entities").add_child(shade)
```
