## enemy.gd
## Stationary hazard placeholder. Damages the player on contact.
## Dashing grants invincibility — player passes through without taking damage.
class_name Enemy
extends Area3D

@export var damage: int = 1

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	# Dash = invincible; pass through freely
	var movement := body.get_node_or_null("MovementComponent") as MovementComponent
	if movement != null and movement.is_dashing:
		return
	if body.has_method("take_damage"):
		var knockback_dir := signf(body.global_position.x - global_position.x)
		body.take_damage(damage, knockback_dir)
