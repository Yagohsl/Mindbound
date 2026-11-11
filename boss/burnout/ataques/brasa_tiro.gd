extends Area2D

@export var damage: int = 10
@export var speed: float = 420.0

var direction: Vector2 = Vector2.RIGHT

func setup(dir: Vector2, custom_speed: float = -1.0) -> void:
	direction = dir.normalized()
	rotation = direction.angle()
	if custom_speed > 0.0:
		speed = custom_speed

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage, global_position)
		queue_free()
	elif body is TileMap or body is StaticBody2D:
		queue_free()

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
