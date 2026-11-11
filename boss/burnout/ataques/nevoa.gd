extends Area2D

@export var duration: float = 8.0
@export var slow_factor: float = 0.5

@onready var screen_overlay: CanvasLayer = get_node_or_null("ScreenOverlay")

var affected_player: Node2D = null
var is_removing: bool = false

func _ready() -> void:
	if screen_overlay:
		screen_overlay.visible = false
	
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.8)
	
	await get_tree().create_timer(duration).timeout
	_remove_cloud()

func _on_body_entered(body: Node2D) -> void:
	if is_removing:
		return

	if body.is_in_group("player"):
		affected_player = body

		# Aplica o slow na velocidade e na velocidade das animações
		if body.has_method("set_area_slow"):
			body.set_area_slow(true, slow_factor)
		else:
			if "slow_multiplier" in body:
				body.slow_multiplier = slow_factor
			if "is_slowed" in body:
				body.is_slowed = true
			if "anim" in body and is_instance_valid(body.anim):
				body.anim.speed_scale = slow_factor

		if screen_overlay:
			screen_overlay.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body == affected_player:
		_restore_player()
	
func _restore_player() -> void:
	if is_instance_valid(affected_player):
		# Restaura completamente as propriedades do herói
		if affected_player.has_method("set_area_slow"):
			affected_player.set_area_slow(false)
		else:
			if "slow_multiplier" in affected_player:
				affected_player.slow_multiplier = 1.0
			if "is_slowed" in affected_player:
				affected_player.is_slowed = false
			# CORREÇÃO PRINCIPAL: Restaura a velocidade padrão das animações (ataque/corrida)
			if "anim" in affected_player and is_instance_valid(affected_player.anim):
				affected_player.anim.speed_scale = 1.0

	affected_player = null
	if is_instance_valid(screen_overlay):
		screen_overlay.visible = false

func _remove_cloud() -> void:
	if is_removing:
		return
	is_removing = true

	set_deferred("monitoring", false)
	_restore_player()

	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	await tween.finished
	queue_free()

func _exit_tree() -> void:
	_restore_player()
