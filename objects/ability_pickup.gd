## ability_pickup.gd
## One-shot collectible — grants an ability and disappears on player contact.
class_name AbilityPickup
extends Area3D

enum Ability { DASH, STUN }

@export var ability: Ability = Ability.DASH

@onready var _mesh: MeshInstance3D = $Mesh

var _collected: bool = false

const _COLOR_DASH := Color(0.95, 0.55, 0.1, 1.0)   # warm orange
const _COLOR_STUN := Color(0.35, 0.7, 1.0, 1.0)    # spirit blue

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var col := _COLOR_DASH if ability == Ability.DASH else _COLOR_STUN
	var mat := StandardMaterial3D.new()
	mat.shading_mode             = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled         = true
	mat.albedo_color             = col
	mat.emission                 = col
	mat.emission_energy_multiplier = 1.5
	_mesh.set_surface_override_material(0, mat)

func _process(_delta: float) -> void:
	_mesh.position.y = sin(Time.get_ticks_msec() * 0.0015) * 0.12
	_mesh.rotation.y += 0.02

func _on_body_entered(body: Node3D) -> void:
	if _collected or not body.is_in_group("player"):
		return
	_collected = true
	_grant(body)
	queue_free()

func _grant(player: Node3D) -> void:
	match ability:
		Ability.DASH:
			var movement := player.get_node_or_null("MovementComponent") as MovementComponent
			if movement != null:
				movement.has_dash = true
		Ability.STUN:
			if player.has_method("unlock_stun"):
				player.unlock_stun()
