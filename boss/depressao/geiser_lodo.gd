extends Area2D

@export var damage: int = 20
@export var paralyze_duration: float = 1.8
@export var telegraph_time: float = 0.8

@onready var collision = $CollisionShape2D
@onready var sprite = $Sprite2D

func _ready() -> void:
	# Começa desativado para o jogador poder ver o aviso no chão e desviar
	collision.disabled = true
	modulate = Color(0.4, 0.2, 0.6, 0.5) # Cor translúcida de aviso
	
	# Tempo de aviso antes da erupção
	await get_tree().create_timer(telegraph_time).timeout
	
	erupt()

func erupt() -> void:
	modulate = Color(0.2, 0.05, 0.3, 1.0) # Cor sólida do lodo
	collision.disabled = false
	
	# Se tiver animação de subida do gêiser, execute-a aqui:
	# $AnimationPlayer.play("erupcao")
	
	# Tempo que o gêiser fica ativo causando dano/paralisia
	await get_tree().create_timer(0.4).timeout
	collision.disabled = true
	
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
