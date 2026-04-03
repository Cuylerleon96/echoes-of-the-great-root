## flyer.gd
## Flying enemy. Hovers in place until player is spotted, then chases indefinitely.
class_name Flyer
extends CharacterBody3D

enum State { IDLE, CHASE, STUNNED }

@export var detect_range: float = 6.5
@export var move_speed: float   = 1.6
@export var damage: int         = 1

@onready var _mesh: MeshInstance3D = $Mesh

var _state: State      = State.IDLE
var _player: Node3D    = null
var _stun_timer: float = 0.0
var _spawn_pos: Vector3

func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	position.z  = 0.0
	_spawn_pos  = global_position
	add_to_group("enemy")
	$HurtZone.body_entered.connect(_on_hurt_zone_body_entered)

func _physics_process(delta: float) -> void:
	velocity.z = 0.0

	match _state:
		State.IDLE:    _tick_idle()
		State.CHASE:   _tick_chase(delta)
		State.STUNNED: _tick_stunned(delta)

	# Gentle hover bob on the mesh (body stays level)
	_mesh.position.y = sin(Time.get_ticks_msec() * 0.002) * 0.07

	move_and_slide()

# ── States ────────────────────────────────────────────────────────────────────

func _tick_idle() -> void:
	velocity = Vector3.ZERO
	_player = _find_player()
	if _player != null and global_position.distance_to(_player.global_position) <= detect_range:
		_state = State.CHASE

func _tick_chase(delta: float) -> void:
	if _player == null:
		_player = _find_player()
	if _player == null:
		return
	var dir := (_player.global_position - global_position)
	dir.z = 0.0
	if dir.length_squared() > 0.01:
		dir = dir.normalized()
	velocity = velocity.lerp(dir * move_speed, 6.0 * delta)

func _tick_stunned(delta: float) -> void:
	# Fall under gravity — dies if it drops past the map
	velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
	velocity.y = maxf(velocity.y - 22.0 * delta, -20.0)
	if global_position.y < -6.0:
		queue_free()
		return
	_stun_timer -= delta
	if _stun_timer <= 0.0:
		velocity = Vector3.ZERO
		_state = State.CHASE

func stun() -> void:
	_state = State.STUNNED
	_stun_timer = 2.5
	velocity = Vector3.ZERO

func reset() -> void:
	global_position = _spawn_pos
	velocity        = Vector3.ZERO
	_state          = State.IDLE
	_stun_timer     = 0.0
	_player         = null

# ── Helpers ───────────────────────────────────────────────────────────────────

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
