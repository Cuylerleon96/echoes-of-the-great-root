## echo.gd
## Echo — the player character. CharacterBody3D, movement on XY plane only.
## Children needed: MovementComponent (Node), Sprite3D, CollisionShape3D
extends CharacterBody3D

@onready var movement: MovementComponent = $MovementComponent
@onready var sprite: Sprite3D = $Sprite3D

func _ready() -> void:
	position.z = 0.0
	up_direction = Vector3.UP
	floor_snap_length = 0.05
	motion_mode = MOTION_MODE_GROUNDED
	add_to_group("player")

func _physics_process(delta: float) -> void:
	movement.tick(delta)
	# Flip sprite to face movement direction
	sprite.flip_h = movement.facing_direction < 0.0
