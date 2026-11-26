extends Area2D

# --- CONFIGURAÇÕES EXPORTADAS ---
@export var duration: float = 8.0
@export var slow_factor: float = 0.5

# --- REFERÊNCIAS DE NÓS (@onready) ---
@onready var screen_overlay: CanvasLayer = get_node_or_null("ScreenOverlay")

# --- VARIÁVEIS INTERNAS ---
var affected_player: Node2D = null
var is_removing: bool = false


# --- MÉTODOS NATIVOS ---
func _ready() -> void:
	add_to_group("burnout_hazards")
	if screen_overlay:
		screen_overlay.visible = false

	modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.8)

	await get_tree().create_timer(duration).timeout
	if not is_removing and is_instance_valid(self):
		_remove_cloud()


func _exit_tree() -> void:
	_restore_player()


# --- MÉTODOS PÚBLICOS ---
func force_cleanup() -> void:
	if not is_removing and is_instance_valid(self):
		_remove_cloud()


# --- SINAIS / CALLBACKS ---
func _on_body_entered(body: Node2D) -> void:
	if is_removing:
		return

	if body.is_in_group("player"):
		affected_player = body

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


# --- MÉTODOS PRIVADOS ---
func _restore_player() -> void:
	if is_instance_valid(affected_player):
		if affected_player.has_method("set_area_slow"):
			affected_player.set_area_slow(false)
		else:
			if "slow_multiplier" in affected_player:
				affected_player.slow_multiplier = 1.0
			if "is_slowed" in affected_player:
				affected_player.is_slowed = false
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

	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	await tween.finished
	if is_instance_valid(self):
		queue_free()
