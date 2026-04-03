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

func _ready() -> void:
	position.z = 0.0
	up_direction = Vector3.UP
	floor_snap_length = 0.05
	motion_mode = MOTION_MODE_GROUNDED
	add_to_group("player")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dash"):
		movement.dash_buffered = true

func _physics_process(delta: float) -> void:
	movement.tick(delta)
	_update_visuals()

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

func _update_animation() -> void:
	var anim := _current_anim_name()

	# Check if this animation has frames loaded yet
	var frames := anim_sprite.sprite_frames
	if frames == null or not frames.has_animation(anim):
		return
	if frames.get_frame_count(anim) == 0:
		return

	# We have real sprites — hide the placeholder mesh
	mesh.visible = false
	anim_sprite.visible = true

	if anim_sprite.animation != anim:
		anim_sprite.play(anim)

func _current_anim_name() -> StringName:
	if movement.is_dashing:
		return &"dash"
	if not is_on_floor():
		if is_on_wall() and velocity.y < 0.0:
			return &"wall_slide"
		return &"jump_rise" if velocity.y > 0.0 else &"jump_fall"
	if absf(velocity.x) > 0.3:
		return &"run"
	return &"idle"
