extends Area2D

@export var fall_speed: float = 380.0
@export var damage: int = 6

func _physics_process(delta: float) -> void:
	# Move verticalmente em linha reta para baixo
	global_position.y += fall_speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
	elif body is TileMap or body is StaticBody2D:
		queue_free() # Destrói ao atingir o chão

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
