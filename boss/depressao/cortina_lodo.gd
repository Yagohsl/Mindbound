extends Area2D

@export var speed: float = 350.0
@export var damage: int = 25

var move_direction: int = 1

func setup(dir: int) -> void:
	move_direction = dir
	if has_node("Sprite2D"):
		$Sprite2D.flip_h = (dir < 0)
	elif has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.flip_h = (dir < 0)

func _physics_process(delta: float) -> void:
	global_position.x += move_direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	# 1. Causa dano no jogador sem sumir (a cortina segue viagem)
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
	
	# 2. Se colidir com paredes, cenário ou chão, a onda é destruída
	elif body is StaticBody2D or body is TileMap or body is TileMapLayer:
		queue_free()

# Trava de segurança: destrói caso passe direto das paredes para fora da tela
func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
