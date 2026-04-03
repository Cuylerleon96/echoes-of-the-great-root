## movement_component.gd
## Hollow Knight-style movement for CharacterBody3D (XY plane, Z always 0).
## NOTE: In Godot 3D, +Y is UP. Jump velocity is POSITIVE. Gravity subtracts.
## World scale: camera.size=10, viewport=720px → 1 unit ≈ 72px.
class_name MovementComponent
extends Node

# ── Horizontal ────────────────────────────────────────────────────────────────
@export var move_speed: float = 5.2           # units/s
@export var ground_acceleration: float = 55.0  # snappy, near-instant ground response
@export var ground_friction: float = 50.0
@export var air_acceleration: float = 22.0
@export var air_friction: float = 10.0
@export var turn_boost: float = 1.8           # extra snap when reversing direction

# ── Jump ──────────────────────────────────────────────────────────────────────
@export var jump_height: float = 1.7          # units    (≈122 px)
@export var jump_time_to_peak: float = 0.38   # seconds
@export var jump_time_to_fall: float = 0.28   # seconds
@export var jump_buffer_time: float = 0.12
@export var coyote_time: float = 0.10
@export var max_fall_speed: float = 12.0      # units/s  (downward, stored as positive limit)
@export var fast_fall_multiplier: float = 1.6

# ── Abilities ─────────────────────────────────────────────────────────────────
@export var has_double_jump: bool = true
@export var has_dash: bool = true
@export var has_wall_jump: bool = true

# ── Double Jump ───────────────────────────────────────────────────────────────
@export var double_jump_multiplier: float = 0.85

# ── Dash ──────────────────────────────────────────────────────────────────────
@export var dash_speed: float = 14.0          # units/s during dash
@export var dash_duration: float = 0.20       # seconds → ~2.8 units distance
@export var dash_cooldown: float = 0.55

# ── Wall Jump ─────────────────────────────────────────────────────────────────
@export var wall_jump_horizontal: float = 4.0
@export var wall_jump_vertical: float = 7.0

# ── Derived (computed in _ready) ──────────────────────────────────────────────
var jump_velocity: float    # positive = upward in 3D
var jump_gravity: float
var fall_gravity: float

# ── Runtime state ─────────────────────────────────────────────────────────────
var facing_direction: float = 1.0
var is_dashing: bool = false
var dash_buffered: bool = false   # set by echo._unhandled_input to avoid missing physics frames

var _body: CharacterBody3D
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _jumps_remaining: int = 1
var _was_on_floor: bool = false
var _dash_dir: float = 1.0

func _ready() -> void:
	_body = get_parent() as CharacterBody3D
	assert(_body != null, "MovementComponent must be a direct child of CharacterBody3D")
	_recalc_jump()

func _recalc_jump() -> void:
	# In 3D: +Y is up. Jump velocity is positive. Gravity decrements velocity.
	jump_velocity = (2.0 * jump_height) / jump_time_to_peak
	jump_gravity  = (2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)
	fall_gravity  = (2.0 * jump_height) / (jump_time_to_fall * jump_time_to_fall)

# ── Call from owner's _physics_process ───────────────────────────────────────
func tick(delta: float) -> void:
	_body.velocity.z = 0.0
	_tick_timers(delta)
	_apply_gravity(delta)
	_handle_dash(delta)
	_handle_jump()
	_handle_horizontal(delta)
	_body.move_and_slide()
	_post_move()

# ── Gravity ───────────────────────────────────────────────────────────────────
func _apply_gravity(delta: float) -> void:
	if is_dashing:
		return
	if _body.is_on_floor():
		_body.velocity.y = 0.0
		return

	# Rising (y > 0) → lighter jump gravity for floaty ascent
	# Falling (y <= 0) → heavier fall gravity for snappy descent
	var grav: float = fall_gravity if _body.velocity.y <= 0.0 else jump_gravity

	# Variable jump height: release jump early to cut the arc
	if not Input.is_action_pressed("jump") and _body.velocity.y > 0.0:
		grav *= 1.8

	# Fast fall: hold down while falling
	if Input.is_action_pressed("move_down") and _body.velocity.y < 0.0:
		grav *= fast_fall_multiplier

	# Subtract gravity (downward), clamp to terminal velocity
	_body.velocity.y = maxf(_body.velocity.y - grav * delta, -max_fall_speed)

# ── Jump ──────────────────────────────────────────────────────────────────────
func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time

	var on_floor := _body.is_on_floor()
	var can_coyote := _coyote_timer > 0.0 and not on_floor

	# Ground / coyote jump
	if _jump_buffer_timer > 0.0 and (on_floor or can_coyote):
		_do_jump(1.0)
		return

	# Double jump (air)
	if has_double_jump and Input.is_action_just_pressed("jump") and not on_floor and _jumps_remaining > 0:
		_do_jump(double_jump_multiplier)
		_jumps_remaining -= 1
		return

	# Wall jump
	if has_wall_jump and Input.is_action_just_pressed("jump") and _body.is_on_wall() and not on_floor:
		var wall_n := _body.get_wall_normal()
		_body.velocity.x = wall_n.x * wall_jump_horizontal
		_body.velocity.y = wall_jump_vertical   # positive = upward
		_jump_buffer_timer = 0.0

func _do_jump(mult: float) -> void:
	_body.velocity.y = jump_velocity * mult     # positive = upward
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0

# ── Horizontal ────────────────────────────────────────────────────────────────
func _handle_horizontal(delta: float) -> void:
	if is_dashing:
		return
	var dir: float = Input.get_axis("move_left", "move_right")
	var accel := ground_acceleration if _body.is_on_floor() else air_acceleration
	var fric  := ground_friction     if _body.is_on_floor() else air_friction

	if dir != 0.0:
		if signf(dir) != signf(_body.velocity.x) and _body.velocity.x != 0.0:
			accel *= turn_boost
		facing_direction = signf(dir)
		_body.velocity.x = move_toward(_body.velocity.x, dir * move_speed, accel * delta)
	else:
		_body.velocity.x = move_toward(_body.velocity.x, 0.0, fric * delta)

# ── Dash ──────────────────────────────────────────────────────────────────────
func _handle_dash(delta: float) -> void:
	if not has_dash:
		dash_buffered = false
		return
	if is_dashing:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			is_dashing = false
			_body.velocity.x = _dash_dir * move_speed
			_body.velocity.y = 0.0
		return
	if (dash_buffered or Input.is_action_just_pressed("dash")) and _dash_cooldown_timer <= 0.0:
		dash_buffered = false
		is_dashing = true
		_dash_timer = dash_duration
		_dash_cooldown_timer = dash_cooldown
		var h := Input.get_axis("move_left", "move_right")
		_dash_dir = signf(h) if h != 0.0 else facing_direction
		_body.velocity = Vector3(_dash_dir * dash_speed, 0.0, 0.0)

# ── Post-move bookkeeping ─────────────────────────────────────────────────────
func _post_move() -> void:
	var on_floor := _body.is_on_floor()
	if _was_on_floor and not on_floor:
		_coyote_timer = coyote_time   # walked off edge — start coyote window
	if on_floor:
		_jumps_remaining = 1          # reset double-jump on landing
	_was_on_floor = on_floor

func _tick_timers(delta: float) -> void:
	_coyote_timer        = maxf(0.0, _coyote_timer - delta)
	_jump_buffer_timer   = maxf(0.0, _jump_buffer_timer - delta)
	_dash_cooldown_timer = maxf(0.0, _dash_cooldown_timer - delta)
