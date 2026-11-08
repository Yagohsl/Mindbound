extends Area2D

@export var duration: float = 8.0
@export var slow_factor: float = 0.5

@onready var screen_overlay: CanvasLayer = get_node_or_null("ScreenOverlay")

var affected_player: Node2D = null

func _ready() -> void:
	if screen_overlay:
		screen_overlay.visible = false
	
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.8)
	
	await get_tree().create_timer(duration).timeout
	_remove_cloud()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		affected_player = body
		
		if "slow_multiplier" in body:
			body.slow_multiplier = slow_factor
		if body.has_method("apply_slow"):
			body.apply_slow(slow_factor, duration)
		
		if screen_overlay:
			screen_overlay.visible = true
			

func _on_body_exited(body: Node2D) -> void:
	if body == affected_player:
		_restore_player()
	
func _restore_player():
	if is_instance_valid(affected_player):
		if "slow_multiplier" in affected_player:
			affected_player.slow_multiplier = 1.0
		if "is_slowed" in affected_player:
			affected_player.is_slowed = false
		if affected_player.has_node("Sprite2D") and affected_player.get_node("Sprite2D").material:
			affected_player.get_node("Sprite2D").material.set_shader_parameter("slow_modifier", 0.0)
	
	affected_player = null
	if screen_overlay:
		screen_overlay.visible = false

func _remove_cloud():
	_restore_player()
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	await tween.finished
	queue_free()
		
