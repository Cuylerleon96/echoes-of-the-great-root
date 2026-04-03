## echo.gd
## Echo — player character. CharacterBody3D, movement on XY plane only.
##
## SPRITE IMPORT — to wire up animations tonight:
##   1. Drop your PNG sprite sheet(s) into res://assets/sprites/echo/
##   2. Select the AnimatedSprite3D node on Echo in the scene
##   3. In the Inspector, open SpriteFrames → click each animation name
##      and drag frames in from the FileSystem panel (bottom-left)
##   4. The mesh placeholder hides itself automatically once any animation
##      has at least one frame loaded.
##
## Animation names already wired (match these exactly in SpriteFrames):
##   idle | run | jump_rise | jump_fall | wall_slide | dash | hurt | death
extends CharacterBody3D

@onready var movement: MovementComponent     = $MovementComponent
@onready var anim_sprite: AnimatedSprite3D   = $AnimatedSprite3D
@onready var mesh: MeshInstance3D            = $Mesh

const SPAWN_POSITION := Vector3(0.0, 0.35, 0.0)
const INVINCIBLE_DURATION: float = 1.0
const STUN_RANGE: float = 2.2
const STUN_COOLDOWN: float = 1.5

@export var has_stun: bool = true   # set false in level scenes until pickup collected
@export var knockback_speed: float = 7.0
@export var knockback_rise: float = 4.5

var max_hp: int = 3
var current_hp: int = 3
var _invincible_timer: float = 0.0

# ── Stun light ────────────────────────────────────────────────────────────────
var _stun_light: OmniLight3D

# ── Particles ─────────────────────────────────────────────────────────────────
const _DUST_COLOR := Color(0.93, 0.88, 0.72, 0.85)  # warm Ghibli cream

var _dust_run:        GPUParticles3D
var _dust_wall_slide: GPUParticles3D
var _dust_wall_jump:  GPUParticles3D
var _dust_stun:       GPUParticles3D

var _stun_cooldown: float = 0.0

var _was_on_floor_p:  bool    = false
var _was_on_wall_p:   bool    = false
var _last_wall_normal: Vector3 = Vector3.ZERO

func _ready() -> void:
	position.z = 0.0
	up_direction = Vector3.UP
	floor_snap_length = 0.05
	motion_mode = MOTION_MODE_GROUNDED
	add_to_group("player")
	_setup_stun_light()
	_setup_particles()

func take_damage(amount: int, knockback_dir: float = 0.0) -> void:
	if _invincible_timer > 0.0:
		return
	current_hp -= amount
	_invincible_timer = INVINCIBLE_DURATION
	velocity.x = knockback_dir * knockback_speed
	velocity.y = knockback_rise
	if current_hp <= 0:
		_die()

func _die() -> void:
	current_hp = max_hp
	global_position = SPAWN_POSITION
	velocity = Vector3.ZERO
	_invincible_timer = INVINCIBLE_DURATION
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.has_method("reset"):
			enemy.reset()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dash"):
		movement.dash_buffered = true
	if event.is_action_pressed("stun"):
		_try_stun()

func unlock_stun() -> void:
	has_stun = true

func _try_stun() -> void:
	if not has_stun or _stun_cooldown > 0.0:
		return
	_stun_cooldown = STUN_COOLDOWN
	_flash_stun_light()
	_dust_stun.restart()
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var e := enemy as Node3D
		if e == null:
			continue
		if global_position.distance_to(e.global_position) <= STUN_RANGE:
			if e.has_method("stun"):
				e.stun()

func _setup_stun_light() -> void:
	_stun_light = OmniLight3D.new()
	_stun_light.light_color         = Color(0.75, 0.95, 1.0)  # cool spirit blue-white
	_stun_light.light_energy        = 0.0
	_stun_light.omni_range          = 4.0
	_stun_light.omni_attenuation    = 1.5
	_stun_light.shadow_enabled      = false
	add_child(_stun_light)

func _flash_stun_light() -> void:
	var tween := create_tween()
	tween.tween_property(_stun_light, "light_energy", 4.0, 0.04)
	tween.tween_property(_stun_light, "light_energy", 0.0, 0.45) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _physics_process(delta: float) -> void:
	_invincible_timer = maxf(0.0, _invincible_timer - delta)
	_stun_cooldown    = maxf(0.0, _stun_cooldown - delta)
	movement.tick(delta)
	_update_visuals()
	_update_particles()

# ── Visuals ───────────────────────────────────────────────────────────────────
func _update_visuals() -> void:
	var facing := movement.facing_direction

	# Placeholder mesh: flip and lean
	mesh.scale.x = facing
	var speed_ratio := absf(velocity.x) / movement.move_speed
	mesh.rotation.z = lerp(mesh.rotation.z, -speed_ratio * 0.18 * facing, 0.25)

	# Sprite: flip to face direction
	anim_sprite.flip_h = facing < 0.0

	_update_animation()
	# Flash during i-frames — _update_animation already set the natural state above,
	# so we can directly assign to whichever visual is active
	if _invincible_timer > 0.0:
		var flash_on := fmod(_invincible_timer, 0.15) > 0.075
		if anim_sprite.visible:
			anim_sprite.visible = flash_on
		else:
			mesh.visible = flash_on

func _update_animation() -> void:
	var anim := _current_anim_name()
	var frames := anim_sprite.sprite_frames
	var sprites_ready := frames != null and frames.has_animation(anim) and frames.get_frame_count(anim) > 0

	if not sprites_ready:
		# Placeholder mode — always restore mesh so flash can toggle it correctly
		mesh.visible = true
		anim_sprite.visible = false
		return

	# Real sprites loaded
	mesh.visible = false
	anim_sprite.visible = true
	if anim_sprite.animation != anim:
		anim_sprite.play(anim)

func _current_anim_name() -> StringName:
	if movement.is_dashing:
		return &"dash"
	if not is_on_floor():
		if is_on_wall() and velocity.y < 0.0:
			var wall_n := get_wall_normal()
			var input_x := Input.get_axis("move_left", "move_right")
			if signf(input_x) == -signf(wall_n.x):
				return &"wall_slide"
		return &"jump_rise" if velocity.y > 0.0 else &"jump_fall"
	if absf(velocity.x) > 0.3:
		return &"run"
	return &"idle"

# ── Particles ─────────────────────────────────────────────────────────────────

func _setup_particles() -> void:
	# Run: small puffs trailing behind feet
	_dust_run = _make_dust(7, 0.45, false, Vector3(0.0, 0.6, 0.0), 55.0)
	_dust_run.position = Vector3(0.0, -0.27, 0.0)
	add_child(_dust_run)

	# Wall slide: scraping dust drifting downward
	_dust_wall_slide = _make_dust(5, 0.35, false, Vector3(0.0, -1.0, 0.0), 22.0)
	add_child(_dust_wall_slide)

	# Wall jump: burst kicking away from the wall
	_dust_wall_jump = _make_dust(12, 0.5, true, Vector3(0.0, 0.5, 0.0), 65.0)
	add_child(_dust_wall_jump)

	# Stun: blue-white spirit wisps bursting outward
	_dust_stun = _make_dust(24, 0.6, true, Vector3(0.0, 1.0, 0.0), 90.0)
	var stun_mat := _dust_stun.process_material as ParticleProcessMaterial
	stun_mat.color                = Color(0.78, 0.95, 1.0, 0.82)
	stun_mat.initial_velocity_min = 1.2
	stun_mat.initial_velocity_max = 2.8
	stun_mat.scale_min            = 0.08
	stun_mat.scale_max            = 0.16
	add_child(_dust_stun)

func _make_dust(amount: int, lifetime: float, one_shot: bool,
		direction: Vector3, spread: float) -> GPUParticles3D:
	var mat := ParticleProcessMaterial.new()
	mat.direction            = direction
	mat.spread               = spread
	mat.initial_velocity_min = 0.4
	mat.initial_velocity_max = 1.3
	mat.gravity              = Vector3(0.0, -1.8, 0.0)
	mat.scale_min            = 0.05
	mat.scale_max            = 0.12
	mat.color                = _DUST_COLOR
	var grad := Gradient.new()
	grad.set_color(0, _DUST_COLOR)
	grad.set_color(1, Color(_DUST_COLOR.r, _DUST_COLOR.g, _DUST_COLOR.b, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	mat.color_ramp = ramp

	# Small sphere — looks like a soft round puff at orthographic scale
	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.10
	var smat := StandardMaterial3D.new()
	smat.transparency  = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode  = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color  = Color.WHITE
	sphere.surface_set_material(0, smat)

	var p := GPUParticles3D.new()
	p.process_material = mat
	p.draw_pass_1      = sphere
	p.amount           = amount
	p.lifetime         = lifetime
	p.one_shot         = one_shot
	p.explosiveness    = 0.85 if one_shot else 0.0
	p.local_coords     = false   # particles stay in world space after emit
	p.emitting         = false
	return p

func _update_particles() -> void:
	var on_floor := is_on_floor()
	var on_wall  := is_on_wall()
	if on_wall:
		_last_wall_normal = get_wall_normal()

	# Running: continuous, direction trails behind movement
	var running := on_floor and absf(velocity.x) > 0.5
	if running:
		(_dust_run.process_material as ParticleProcessMaterial).direction = \
				Vector3(-signf(velocity.x), 0.6, 0.0)
	_dust_run.emitting = running

	# Wall slide: continuous, positioned at the wall face
	var wall_sliding := on_wall and not on_floor and velocity.y < 0.0
	if wall_sliding:
		_dust_wall_slide.position = Vector3(-_last_wall_normal.x * 0.2, 0.0, 0.0)
	_dust_wall_slide.emitting = wall_sliding

	# Jump takeoff: sculpted puff cloud
	if _was_on_floor_p and not on_floor and velocity.y > 0.0:
		_spawn_jump_dust()

	# Wall jump: one-shot burst leaving the wall upward
	if _was_on_wall_p and not on_wall and not on_floor and velocity.y > 0.0:
		_dust_wall_jump.position = Vector3(_last_wall_normal.x * 0.2, 0.0, 0.0)
		_dust_wall_jump.restart()

	_was_on_floor_p = on_floor
	_was_on_wall_p  = on_wall

func _spawn_jump_dust() -> void:
	var foot := global_position + Vector3(0.0, -0.3, 0.0)
	_spawn_dust_puff(foot + Vector3(-0.16, 0.0, 0.0))
	_spawn_dust_puff(foot + Vector3( 0.16, 0.0, 0.0))

func _spawn_dust_puff(world_pos: Vector3) -> void:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode  = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color  = _DUST_COLOR

	var sphere := SphereMesh.new()
	sphere.radius = 0.10
	sphere.height  = 0.20
	sphere.surface_set_material(0, mat)

	var puff := MeshInstance3D.new()
	puff.mesh  = sphere
	puff.scale = Vector3(0.2, 0.2, 0.2)
	get_parent().add_child(puff)
	puff.global_position = world_pos

	# Squash outward (wider) and flatten (shorter) — classic cartoon ground puff
	var end_scale := Vector3(1.9, 0.18, 1.9)
	var tween := puff.create_tween().set_parallel(true)
	tween.tween_property(puff, "scale", end_scale, 0.30) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color",
			Color(_DUST_COLOR.r, _DUST_COLOR.g, _DUST_COLOR.b, 0.0), 0.28) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(puff.queue_free)
