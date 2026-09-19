extends Area2D

@export var speed: float = 320.0
@export var damage: int = 10
@export var slow_factor: float = 0.5   # Reduz a velocidade pela metade (50%)
@export var slow_duration: float = 2.5 # Duração da lentidão em segundos
var direction: Vector2 = Vector2.ZERO

func setup(target_direction: Vector2) -> void:
	direction = target_direction.normalized()
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		# Aplica dano padrão
		if body.has_method("take_damage"):
			body.take_damage(damage, global_position)
		
		# Aplica o efeito de lentidão
		if body.has_method("apply_slow"):
			body.apply_slow(slow_factor, slow_duration)
			
		queue_free()
	elif body is TileMap or body is StaticBody2D:
		queue_free() # Destrói ao atingir paredes/chão

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
