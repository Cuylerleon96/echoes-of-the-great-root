## pouncer.gd
## Enemy: spots player → 1s wind-up → pounces → recovers → repeats.
class_name Pouncer
extends CharacterBody3D

enum State { IDLE, ALERT, POUNCE, RECOVER, RETURN, STUNNED }

@export var detect_range: float      = 5.0
@export var max_pounce_distance: float = 4.0  # aborts launch if player is farther than this
@export var alert_duration: float    = 1.4  # wind-up before launch
@export var arc_height: float        = 1.5  # peak height above launch point
@export var recover_duration: float  = 0.7
@export var return_speed: float      = 1.2   # walk speed back to spawn
@export var lost_player_time: float  = 3.0   # seconds out of range before returning
@export var damage: int            = 1
@export var gravity: float         = 22.0

@onready var _mesh: MeshInstance3D = $Mesh

var _state: State          = State.IDLE
var _timer: float          = 0.0
var _stun_timer: float     = 0.0
var _pounce_elapsed: float = 0.0
var _lost_timer: float     = 0.0
var _spawn_pos: Vector3
var _player: Node3D        = null

func _ready() -> void:
	up_direction      = Vector3.UP
	floor_snap_length = 0.05
	motion_mode       = MOTION_MODE_GROUNDED
	position.z        = 0.0
	_spawn_pos        = global_position
	add_to_group("enemy")
	$HurtZone.body_entered.connect(_on_hurt_zone_body_entered)

func _physics_process(delta: float) -> void:
	velocity.z = 0.0

	# Gravity: ground it between pounces, free-fall during pounce
	if is_on_floor() and _state != State.POUNCE:
		velocity.y = 0.0
	else:
		velocity.y = maxf(velocity.y - gravity * delta, -20.0)

	match _state:
		State.IDLE:    _tick_idle(delta)
		State.ALERT:   _tick_alert(delta)
		State.POUNCE:  _tick_pounce(delta)
		State.RECOVER: _tick_recover(delta)
		State.RETURN:  _tick_return(delta)
		State.STUNNED: _tick_stunned(delta)

	move_and_slide()

# ── States ────────────────────────────────────────────────────────────────────

func _tick_idle(delta: float) -> void:
	velocity.x = 0.0
	_player = _find_player()
	var in_range := _player != null and global_position.distance_to(_player.global_position) <= detect_range
	if in_range:
		_lost_timer = 0.0
		_state = State.ALERT
		_timer = alert_duration
	else:
		_lost_timer += delta
		if _lost_timer >= lost_player_time:
			_lost_timer = 0.0
			_state = State.RETURN

func _tick_alert(delta: float) -> void:
	velocity.x = 0.0
	_face_player()
	_timer -= delta
	if _timer <= 0.0:
		_launch()

func _launch() -> void:
	if _player == null:
		_state = State.IDLE
		return

	var start  := global_position
	var target := _player.global_position
	var dx     := target.x - start.x
	var dy     := target.y - start.y

	if absf(dx) > max_pounce_distance:
		_state = State.RECOVER
		_timer = 0.4
		return

	# Arc must be tall enough to clear the target's height
	var h  := maxf(arc_height, dy + 0.2)
	var vy := sqrt(2.0 * gravity * h)

	# Time of flight: solve dy = vy*t - 0.5*g*t² → take the descending root
	var disc := vy * vy - 2.0 * gravity * dy
	if disc < 0.0:
		_state = State.IDLE
		return
	var t  := (vy + sqrt(disc)) / gravity
	var vx := dx / t

	velocity.x = vx
	velocity.y = vy
	_pounce_elapsed = 0.0
	_state = State.POUNCE

func _tick_pounce(delta: float) -> void:
	_pounce_elapsed += delta
	# Small grace window so it doesn't abort instantly on launch frame
	if _pounce_elapsed > 0.12 and is_on_floor():
		velocity.x = 0.0
		_state = State.RECOVER
		_timer = recover_duration

func _tick_recover(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
	_timer -= delta
	if _timer <= 0.0:
		_state = State.IDLE

func _tick_return(_delta: float) -> void:
	# If player comes back into range, resume hunting
	_player = _find_player()
	if _player != null and global_position.distance_to(_player.global_position) <= detect_range:
		_lost_timer = 0.0
		_state = State.IDLE
		return

	var dx := _spawn_pos.x - global_position.x
	if absf(dx) <= 0.2:
		velocity.x = 0.0
		_state = State.IDLE
		return

	velocity.x = signf(dx) * return_speed
	var dir := signf(dx)
	if dir != 0.0:
		_mesh.scale.x = dir

func _tick_stunned(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
	_stun_timer -= delta
	if _stun_timer <= 0.0:
		_state = State.IDLE

func stun() -> void:
	_state = State.STUNNED
	_stun_timer = 2.5
	velocity.x = 0.0

func reset() -> void:
	global_position = _spawn_pos
	velocity        = Vector3.ZERO
	_state          = State.IDLE
	_timer          = 0.0
	_stun_timer     = 0.0
	_pounce_elapsed = 0.0
	_lost_timer     = 0.0
	_player         = null

# ── Helpers ───────────────────────────────────────────────────────────────────

func _face_player() -> void:
	if _player == null:
		return
	var dir := signf(_player.global_position.x - global_position.x)
	if dir != 0.0:
		_mesh.scale.x = dir

func _find_player() -> Node3D:
	var group := get_tree().get_nodes_in_group("player")
	return group[0] as Node3D if not group.is_empty() else null

func _on_hurt_zone_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	var movement := body.get_node_or_null("MovementComponent") as MovementComponent
	if movement != null and movement.is_dashing:
		return
	if body.has_method("take_damage"):
		var knockback_dir := signf(body.global_position.x - global_position.x)
		body.take_damage(damage, knockback_dir)
