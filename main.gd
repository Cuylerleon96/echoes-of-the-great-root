## main.gd
## Camera follow with lookahead + soft deadzone, and fall respawn.
extends Node3D

@onready var camera: Camera3D        = $Camera3D
@onready var echo:   CharacterBody3D = $Echo

## How far ahead of the player the camera peeks (units)
@export var lookahead_x:    float = 2.2
## How quickly the lookahead shifts when the player turns
@export var lookahead_speed: float = 3.0

## Horizontal band inside which the camera doesn't move at all
@export var dead_zone_x: float = 0.5
## Vertical band inside which the camera doesn't move
@export var dead_zone_y: float = 1.0

## Base follow speeds — ramp up automatically when the player is far outside the zone
@export var follow_speed_x: float = 5.5
@export var follow_speed_y: float = 4.5

## Camera sits this many units above the player and this far back on Z
@export var camera_y_offset: float = 1.5
@export var camera_z_depth:  float = 15.0

@export var respawn_y_threshold: float = -4.0

const SPAWN_POSITION := Vector3(0.0, 0.35, 0.0)

var _lookahead_offset: float = 0.0
var _last_safe_pos: Vector3

func _ready() -> void:
	# Snap instantly to player so the camera doesn't fly in on the first frame
	var p := echo.global_position
	camera.global_position = Vector3(p.x, p.y + camera_y_offset, camera_z_depth)
	_last_safe_pos = p

func _physics_process(delta: float) -> void:
	if echo.is_on_floor():
		_last_safe_pos = echo.global_position
	_follow_camera(delta)
	_check_fall()

func _follow_camera(delta: float) -> void:
	var player   := echo.global_position
	var movement := echo.get_node_or_null("MovementComponent") as MovementComponent
	var facing   := movement.facing_direction if movement != null else 1.0

	# Lookahead: smoothly shift the camera target ahead of the player's facing direction
	_lookahead_offset = lerp(_lookahead_offset, facing * lookahead_x, lookahead_speed * delta)

	var target_x := player.x + _lookahead_offset
	var target_y := player.y + camera_y_offset
	var cam      := camera.global_position

	# ── Horizontal deadzone ────────────────────────────────────────────────────
	var dx := target_x - cam.x
	if absf(dx) > dead_zone_x:
		# Speed ramps up the further outside the zone the player is
		var speed := follow_speed_x * (1.0 + (absf(dx) - dead_zone_x) * 0.6)
		cam.x = lerp(cam.x, target_x, clampf(speed * delta, 0.0, 1.0))

	# ── Vertical deadzone ──────────────────────────────────────────────────────
	var dy := target_y - cam.y
	if absf(dy) > dead_zone_y:
		var speed := follow_speed_y * (1.0 + (absf(dy) - dead_zone_y) * 0.4)
		cam.y = lerp(cam.y, target_y, clampf(speed * delta, 0.0, 1.0))

	cam.z = camera_z_depth
	camera.global_position = cam

func _check_fall() -> void:
	if echo.global_position.y < respawn_y_threshold:
		echo.global_position = _last_safe_pos
		echo.velocity        = Vector3.ZERO
		echo.take_damage(1)
		# If take_damage triggered _die() (hp hit 0), _die() already overwrote
		# global_position with SPAWN_POSITION — so death respawn is handled automatically.
