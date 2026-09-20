extends Area2D

@export var damage: int = 20
@export var paralyze_duration: float = 1.8
@export var telegraph_time: float = 1.2

@onready var collision = $CollisionShape2D
@onready var sprite = $Sprite2D

func _ready() -> void:
	# Começa desativado para o jogador poder ver o aviso no chão e desviar
	collision.disabled = true
	$AnimationPlayer.play("preparacao")

	# Tempo de aviso antes da erupção
	await get_tree().create_timer(telegraph_time).timeout
	

	erupt()

func erupt() -> void:
	$AnimationPlayer.play("erupcao")
	await $AnimationPlayer.animation_finished
	
	# Pequeno fade out antes de sumir
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage, global_position)
		if body.has_method("apply_paralysis"):
			body.apply_paralysis(paralyze_duration)
