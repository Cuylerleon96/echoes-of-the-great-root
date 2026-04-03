## flyer.gd
## Flying enemy. Hovers in place until player is spotted, then chases indefinitely.
class_name Flyer
extends CharacterBody3D

enum State { IDLE, CHASE, STUNNED }

@export var detect_range: float = 6.5
@export var move_speed: float   = 1.6
@export var damage: int         = 1

@onready var _mesh: MeshInstance3D        = $Mesh
@onready var _anim_sprite: AnimatedSprite3D = $AnimatedSprite3D

var _state: State      = State.IDLE
var _player: Node3D    = null
var _stun_timer: float = 0.0
var _spawn_pos: Vector3
var _dead: bool        = false

func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	position.z  = 0.0
	_spawn_pos  = global_position
	add_to_group("enemy")
	$HurtZone.body_entered.connect(_on_hurt_zone_body_entered)

func _physics_process(delta: float) -> void:
	if _dead:
		return
	velocity.z = 0.0

	match _state:
		State.IDLE:    _tick_idle()
		State.CHASE:   _tick_chase(delta)
		State.STUNNED: _tick_stunned(delta)

	# Gentle hover bob on the mesh (body stays level)
	_mesh.position.y = sin(Time.get_ticks_msec() * 0.002) * 0.07
	_anim_sprite.position.y = _mesh.position.y

	move_and_slide()
	_update_animation()

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
	velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
	velocity.y = maxf(velocity.y - 22.0 * delta, -20.0)
	if global_position.y < -6.0:
		_kill()
		return
	_stun_timer -= delta
	if _stun_timer <= 0.0:
		velocity = Vector3.ZERO
		_state = State.CHASE

func _kill() -> void:
	_dead     = true
	velocity  = Vector3.ZERO
	hide()

func stun() -> void:
	_state = State.STUNNED
	_stun_timer = 2.5
	velocity = Vector3.ZERO

func reset() -> void:
	_dead           = false
	_state          = State.IDLE
	_stun_timer     = 0.0
	_player         = null
	velocity        = Vector3.ZERO
	global_position = _spawn_pos
	show()

# ── Animation ─────────────────────────────────────────────────────────────────

func _current_anim_name() -> StringName:
	if _dead:
		return &"death"
	match _state:
		State.CHASE:   return &"chase"
		State.STUNNED: return &"stunned"
	return &"idle"

func _update_animation() -> void:
	if absf(velocity.x) > 0.05:
		_anim_sprite.flip_h = velocity.x < 0.0
		_mesh.scale.x = signf(velocity.x)

	var anim := _current_anim_name()
	var frames := _anim_sprite.sprite_frames
	var sprites_ready := frames != null \
			and frames.has_animation(anim) \
			and frames.get_frame_count(anim) > 0
	if not sprites_ready:
		_mesh.visible = true
		_anim_sprite.visible = false
		return
	_mesh.visible = false
	_anim_sprite.visible = true
	if _anim_sprite.animation != anim:
		_anim_sprite.play(anim)

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
	if not body.has_method("take_damage"):
		return
	# If stacked on the same X, fall back to the opposite of approach direction
	var dx := body.global_position.x - global_position.x
	var knockback_dir: float = signf(dx) if absf(dx) > 0.05 else \
			(-signf(velocity.x) if absf(velocity.x) > 0.1 else 1.0)
	body.take_damage(damage, knockback_dir)
	# Recoil away so the flyer doesn't sit inside the player during i-frames
	velocity = Vector3(-knockback_dir * move_speed * 2.5, move_speed, 0.0)
