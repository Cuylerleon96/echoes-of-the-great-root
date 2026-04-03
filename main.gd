## main.gd
## Camera follow + respawn on fall.
extends Node3D

@onready var camera: Camera3D = $Camera3D
@onready var echo: CharacterBody3D = $Echo

@export var follow_speed: float = 8.0
@export var camera_offset: Vector3 = Vector3(0.0, 1.5, 15.0)
@export var respawn_y_threshold: float = -4.0   # fall below this → respawn

const SPAWN_POSITION := Vector3(0.0, 0.35, 0.0)

func _physics_process(delta: float) -> void:
	_follow_camera(delta)
	_check_fall()

func _follow_camera(delta: float) -> void:
	var target := echo.global_position + camera_offset
	camera.global_position = camera.global_position.lerp(target, follow_speed * delta)
	camera.global_position.z = camera_offset.z

func _check_fall() -> void:
	if echo.global_position.y < respawn_y_threshold:
		echo.global_position = SPAWN_POSITION
		echo.velocity = Vector3.ZERO
