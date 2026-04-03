---
name: hollow-knight-movement
description: Precise platformer physics matching Hollow Knight's feel — coyote time, jump buffering, variable jump height, dash, wall-slide, wall-jump, and nail-pogo in Godot 4 with CharacterBody2D.
---

# Hollow Knight-Style Movement Physics (Godot 4)

## Core Philosophy
Hollow Knight's movement is *tight*, *responsive*, and *snappy*. Every input is processed immediately. Latency between button press and character response is zero. All momentum feels weighted but controllable.

## CharacterBody2D Setup

```gdscript
# movement_component.gd — attach to CharacterBody2D
extends CharacterBody2D

# ── Horizontal ────────────────────────────────────────────────
@export var move_speed: float = 220.0
@export var ground_acceleration: float = 2200.0
@export var ground_friction: float = 2200.0
@export var air_acceleration: float = 1400.0
@export var air_friction: float = 800.0
@export var turn_boost: float = 1.5       # extra accel when reversing direction

# ── Jump ──────────────────────────────────────────────────────
@export var jump_height: float = 96.0     # pixels at peak
@export var jump_time_to_peak: float = 0.4
@export var jump_time_to_fall: float = 0.3
@export var jump_buffer_time: float = 0.12
@export var coyote_time: float = 0.10
@export var max_fall_speed: float = 700.0
@export var fall_gravity_multiplier: float = 1.6  # fast fall when holding down

# ── Dash ──────────────────────────────────────────────────────
@export var dash_speed: float = 500.0
@export var dash_duration: float = 0.18
@export var dash_cooldown: float = 0.6
@export var ground_dash_only: bool = false  # set false for Hollow Knight air dash

# ── Wall Slide / Jump ─────────────────────────────────────────
@export var wall_slide_gravity: float = 120.0
@export var wall_jump_horizontal: float = 260.0
@export var wall_jump_vertical: float = 400.0
@export var wall_stick_time: float = 0.12  # brief pause before sliding

# ── Derived (computed in _ready) ─────────────────────────────
var jump_velocity: float
var jump_gravity: float
var fall_gravity: float

# ── State ────────────────────────────────────────────────────
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _is_dashing: bool = false
var _dash_direction: Vector2 = Vector2.RIGHT
var _wall_stick_timer: float = 0.0
var _was_on_floor: bool = false

func _ready() -> void:
    # Physics-based jump feel (same formula Team Cherry uses)
    jump_velocity = -(2.0 * jump_height) / jump_time_to_peak
    jump_gravity  = (2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)
    fall_gravity  = (2.0 * jump_height) / (jump_time_to_fall * jump_time_to_fall)

func _physics_process(delta: float) -> void:
    _tick_timers(delta)
    _apply_gravity(delta)
    _handle_dash(delta)
    _handle_jump()
    _handle_horizontal(delta)
    move_and_slide()
    _post_move()

# ── Gravity ───────────────────────────────────────────────────
func _apply_gravity(delta: float) -> void:
    if _is_dashing:
        return
    if is_on_floor():
        velocity.y = 0.0
        return
    var grav = fall_gravity if velocity.y >= 0 else jump_gravity
    # Fast-fall: hold down to fall faster
    if Input.is_action_pressed("move_down") and velocity.y > 0:
        grav *= fall_gravity_multiplier
    # Variable jump height: release jump early to cut arc
    if not Input.is_action_pressed("jump") and velocity.y < 0:
        grav *= 1.8
    velocity.y = min(velocity.y + grav * delta, max_fall_speed)

# ── Jump ──────────────────────────────────────────────────────
func _handle_jump() -> void:
    if Input.is_action_just_pressed("jump"):
        _jump_buffer_timer = jump_buffer_time

    var can_coyote = _coyote_timer > 0.0 and not is_on_floor()
    var can_jump = is_on_floor() or can_coyote

    if _jump_buffer_timer > 0.0 and can_jump:
        velocity.y = jump_velocity
        _jump_buffer_timer = 0.0
        _coyote_timer = 0.0

    # Wall jump
    if Input.is_action_just_pressed("jump") and is_on_wall() and not is_on_floor():
        var wall_normal = get_wall_normal()
        velocity.x = wall_normal.x * wall_jump_horizontal
        velocity.y = -wall_jump_vertical
        _wall_stick_timer = 0.0

# ── Horizontal ────────────────────────────────────────────────
func _handle_horizontal(delta: float) -> void:
    if _is_dashing:
        return
    var dir = Input.get_axis("move_left", "move_right")
    var accel = ground_acceleration if is_on_floor() else air_acceleration
    var fric  = ground_friction     if is_on_floor() else air_friction

    if dir != 0.0:
        # Turn boost: extra snap when reversing
        if sign(dir) != sign(velocity.x) and velocity.x != 0.0:
            accel *= turn_boost
        velocity.x = move_toward(velocity.x, dir * move_speed, accel * delta)
    else:
        velocity.x = move_toward(velocity.x, 0.0, fric * delta)

# ── Dash ──────────────────────────────────────────────────────
func _handle_dash(delta: float) -> void:
    if _is_dashing:
        _dash_timer -= delta
        if _dash_timer <= 0.0:
            _is_dashing = false
            velocity.x = sign(_dash_direction.x) * move_speed  # exit momentum
        return

    if Input.is_action_just_pressed("dash") and _dash_cooldown_timer <= 0.0:
        if ground_dash_only and not is_on_floor():
            return
        _is_dashing = true
        _dash_timer = dash_duration
        _dash_cooldown_timer = dash_cooldown
        var h = Input.get_axis("move_left", "move_right")
        _dash_direction = Vector2(h if h != 0.0 else sign(velocity.x), 0.0).normalized()
        if _dash_direction == Vector2.ZERO:
            _dash_direction = Vector2.RIGHT
        velocity = _dash_direction * dash_speed
        velocity.y = 0.0  # no gravity during dash

# ── Wall Slide ────────────────────────────────────────────────
func _get_wall_slide_gravity() -> float:
    if is_on_wall() and not is_on_floor() and velocity.y > 0:
        return wall_slide_gravity
    return 0.0  # handled in _apply_gravity

# ── Post-move bookkeeping ─────────────────────────────────────
func _post_move() -> void:
    if _was_on_floor and not is_on_floor():
        _coyote_timer = coyote_time  # walked off edge — start coyote window
    _was_on_floor = is_on_floor()

func _tick_timers(delta: float) -> void:
    _coyote_timer         = max(0.0, _coyote_timer - delta)
    _jump_buffer_timer    = max(0.0, _jump_buffer_timer - delta)
    _dash_cooldown_timer  = max(0.0, _dash_cooldown_timer - delta)
    if _wall_stick_timer > 0.0:
        _wall_stick_timer = max(0.0, _wall_stick_timer - delta)
```

## Input Map (Project Settings → Input Map)
```
jump        → Space / Gamepad A
dash        → Left Shift / Gamepad X / Gamepad RB
move_left   → A / Left Arrow / Gamepad Left
move_right  → D / Right Arrow / Gamepad Right
move_down   → S / Down Arrow / Gamepad Down
attack      → J / Z / Gamepad B
```

## Nail Pogo (Bounce on downward strike)
```gdscript
# In attack system — call this when nail hits enemy/object below player
func nail_pogo_bounce() -> void:
    velocity.y = jump_velocity * 0.85  # slightly less than full jump
```

## Collision Layer Conventions
- Layer 1: World/terrain
- Layer 2: Player
- Layer 3: Enemies
- Layer 4: Hazards / spikes
- Layer 5: Interactables

## Key Godot 4 Notes
- Use `CharacterBody2D` + `move_and_slide()` — not RigidBody2D
- `is_on_floor()` checks the `up_direction` vector (default `Vector2.UP`)
- Set `floor_snap_length = 4.0` on CharacterBody2D for smooth slope descent
- `motion_mode = MOTION_MODE_GROUNDED` for platformers
- For one-way platforms: use collision layer + `set_collision_mask_value()` momentarily while pressing down+jump
