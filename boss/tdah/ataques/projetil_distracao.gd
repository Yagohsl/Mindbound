extends Area2D

enum State {
	MOVING,    # Projétil em voo contínuo (leque)
	TELEGRAPH, # Fase de aviso: tremendo/volátil, sem causar dano ainda (modo estático)
	ACTIVE,    # Fase ativa: estático/vibrante, causa dano se for perigoso
	DISSOLVE   # Dissolve e some
}

@export var damage: int = 15
@export var telegraph_duration: float = 1.0  # Tempo para o jogador reagir
@export var active_duration: float = 0.8     # Tempo que fica ativo causando dano

var is_dangerous: bool = false
var base_color: Color = Color.WHITE
var current_state: State = State.TELEGRAPH

# Para modo voo (MOVING)
var velocity: Vector2 = Vector2.ZERO
var speed: float = 400.0
var perpendicular: Vector2 = Vector2.ZERO
var wave_frequency: float = 0.0
var wave_amplitude: float = 0.0

# Para modo estático (TELEGRAPH / ACTIVE)
var origin_pos: Vector2 = Vector2.ZERO
var jitter_speed: float = 28.0
var jitter_intensity: float = 3.5
var time_passed: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# Setup para modo estático/volátil
func setup(p_pos: Vector2, p_is_dangerous: bool, p_color: Color, p_telegraph_time: float = 1.0, p_active_time: float = 0.8) -> void:
	current_state = State.TELEGRAPH
	global_position = p_pos
	origin_pos = p_pos
	is_dangerous = p_is_dangerous
	base_color = p_color
	telegraph_duration = p_telegraph_time
	active_duration = p_active_time

	jitter_speed = randf_range(24.0, 38.0)
	jitter_intensity = randf_range(2.5, 4.5)

	if sprite:
		sprite.modulate = Color(base_color.r, base_color.g, base_color.b, 0.5)
		sprite.scale = Vector2(0.5, 0.5)
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(2.5, 2.5), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_start_lifecycle()

# Setup para modo disparo em leque (projétil em movimento)
func setup_moving(p_pos: Vector2, p_dir: Vector2, p_speed: float, p_is_dangerous: bool, p_color: Color) -> void:
	current_state = State.MOVING
	global_position = p_pos
	speed = p_speed
	velocity = p_dir.normalized() * speed
	is_dangerous = p_is_dangerous
	base_color = p_color
	perpendicular = Vector2(-p_dir.y, p_dir.x).normalized()
	wave_frequency = randf_range(7.0, 15.0)
	wave_amplitude = randf_range(15.0, 30.0)

	if sprite:
		sprite.modulate = p_color
		sprite.scale = Vector2(2.5, 2.5)

func _process(delta: float) -> void:
	time_passed += delta

	match current_state:
		State.MOVING:
			var wave_offset = perpendicular * sin(time_passed * wave_frequency) * wave_amplitude * delta * 5.0
			global_position += (velocity * delta) + wave_offset
			rotation = velocity.angle()
			if global_position.x < -100 or global_position.x > 1400 or global_position.y < -150 or global_position.y > 850:
				queue_free()

		State.TELEGRAPH:
			# Efeito volátil / trêmulo no lugar
			var offset_x = sin(time_passed * jitter_speed) * jitter_intensity
			var offset_y = cos(time_passed * (jitter_speed * 1.3)) * jitter_intensity
			global_position = origin_pos + Vector2(offset_x, offset_y)
			
			# Pulso visual de advertência
			if sprite:
				var pulse = 0.45 + 0.35 * abs(sin(time_passed * 12.0))
				sprite.modulate.a = pulse

		State.ACTIVE:
			# Vibração de alta frequência rápida ("estalo/ativo")
			var micro_shake = Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))
			global_position = origin_pos + micro_shake

func _start_lifecycle() -> void:
	await get_tree().create_timer(telegraph_duration, false).timeout
	if not is_inside_tree(): return

	current_state = State.ACTIVE
	if sprite:
		# Brilha com força total e expande um pouco
		sprite.modulate = base_color
		var pop_tween = create_tween()
		pop_tween.tween_property(sprite, "scale", Vector2(3.2, 3.2), 0.08)
		pop_tween.tween_property(sprite, "scale", Vector2(2.6, 2.6), 0.1)

	_check_overlapping_bodies()

	await get_tree().create_timer(active_duration, false).timeout
	if not is_inside_tree(): return

	# 3. Fase DISSOLVE
	current_state = State.DISSOLVE
	if sprite:
		var fade_tween = create_tween()
		fade_tween.set_parallel(true)
		fade_tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
		fade_tween.tween_property(sprite, "scale", Vector2.ZERO, 0.2)
		await fade_tween.finished

	queue_free()

func _check_overlapping_bodies() -> void:
	if current_state != State.ACTIVE or not is_dangerous:
		return
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			_apply_damage_to_player(body)
			break

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if not is_dangerous:
			return # Distração inofensiva atravessa sem efeito
			
		if current_state in [State.ACTIVE, State.MOVING]:
			_apply_damage_to_player(body)
	elif (body is TileMap or body is StaticBody2D) and current_state == State.MOVING:
		queue_free()

func _apply_damage_to_player(body: Node2D) -> void:
	if ("is_dashing" in body and body.is_dashing) or ("is_dash_invincible" in body and body.is_dash_invincible):
		return

	if body.has_method("take_damage"):
		body.take_damage(damage, global_position)

	# Efeito de feedback: expande e brilha para destacar que este causou o dano real
	_play_impact_expansion()

func _play_impact_expansion() -> void:
	# Desativa colisão para não dar múltiplos hits enquanto expande
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	if sprite:
		var current_scale = sprite.scale
		var impact_tween = create_tween()
		impact_tween.set_parallel(true)
		# Expande levemente (pop de impacto) e desvanece
		impact_tween.tween_property(sprite, "scale", current_scale * 1.5, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		impact_tween.tween_property(sprite, "modulate:a", 0.0, 0.15)
		await impact_tween.finished
		queue_free()
	else:
		queue_free()
