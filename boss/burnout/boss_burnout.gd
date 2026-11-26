extends BossBase

enum State {
	IDLE,
	RUN,
	SOOT_CLOUD,
	EMBER_RAIN_PREP,
	EMBER_RAIN,
	CORE_COLLAPSE_PREP,
	EXHAUSTED,
	EXHAUSTION_BEAM_PREP,
	EXHAUSTION_BEAM,
	BURST_SHOT,
	DEATH
}

const DECELERATING_STATES: Array[State] = [
	State.SOOT_CLOUD,
	State.EMBER_RAIN_PREP,
	State.EMBER_RAIN,
	State.BURST_SHOT
]

const KNOCKBACK_IMMUNE_STATES: Array[State] = [
	State.CORE_COLLAPSE_PREP,
	State.EXHAUSTED,
	State.EXHAUSTION_BEAM_PREP,
	State.EXHAUSTION_BEAM,
	State.BURST_SHOT,
	State.DEATH
]

@export_group("Arena Bounds")
@export var arena_min_x: float = 120.0
@export var arena_max_x: float = 1160.0

@export_group("Ataques")
@export var soot_cloud_scene: PackedScene

@export_group("Ataque: Rajada de Brasas")
@export var burst_projectile_scene: PackedScene
@export var burst_count_min: int = 4
@export var burst_count_max: int = 5
@export var burst_fire_interval: float = 0.3
@export var burst_spread_degrees: float = 6.0
@export var burst_projectile_speed: float = 480.0
@export var burst_prep_time: float = 0.45

@export_group("Ataque: Feixe de Exaustão")
@export var beam_prep_time: float = 0.65
@export var beam_cast_range: float = 420.0
@export var beam_max_distance: float = 540.0
@export var beam_break_damage_threshold: int = 40
@export var beam_cooldown_multiplier: float = 2.0
@export var beam_drain_damage: int = 2
@export var beam_drain_interval: float = 0.5
@export var beam_max_duration: float = 8.0
@export var beam_segments: int = 12
@export var beam_wave_amplitude: float = 5.5
@export var player_chest_offset: Vector2 = Vector2.ZERO

@export_group("Ataque: Colapso do Núcleo")
@export var collapse_prep_duration: float = 2.0
@export var exhausted_min_duration: float = 3.0
@export var exhausted_max_duration: float = 4.0
@export var collapse_shake_intensity: float = 4.5
@export var exhausted_damage_multiplier: float = 1.5
@export_range(0.0, 1.0, 0.05) var core_collapse_hp_threshold: float = 0.5
@export var min_attacks_between_collapses: int = 2

@export_group("Ataque: Chuva de Brasas")
@export var ember_scene: PackedScene
@export var fire_puddle_scene: PackedScene
@export var ember_prep_time: float = 0.8
@export var ember_count: int = 6
@export var ember_min_spacing: float = 130.0
@export var ember_flight_time: float = 1.15
@export var ember_arc_height: float = 280.0
@export var ember_spawn_interval: float = 0.14
@export var ground_collision_mask: int = 1
@export var ground_offset_y: float = 0.0
@export_range(0.0, 1.0, 0.05) var ember_rain_hp_threshold: float = 1.0

@onready var shoot_point: Marker2D = get_node_or_null("PontoDeTiro")
@onready var body_collision: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var damage_collision: CollisionShape2D = get_node_or_null("DamageArea/CollisionShape2D")
@onready var exhaustion_beam: Line2D = get_node_or_null("ExhaustionBeam")
@onready var beam_soot_particles: CPUParticles2D = get_node_or_null("BeamSootParticles")
@onready var core_particles: CPUParticles2D = get_node_or_null("SparksParticles")
@onready var collapse_smoke: CPUParticles2D = get_node_or_null("SmokeParticles")

var current_state: State = State.IDLE
var last_attack: State = State.IDLE
var current_life_percent: float = 1.0
var walk_direction: int = -1

var beam_damage_taken: int = 0
var beam_drain_timer: float = 0.0
var beam_elapsed: float = 0.0

var phase_two_collapse_triggered: bool = false
var pending_guaranteed_collapse: bool = false
var attacks_since_collapse: int = 0

var base_sprite_pos: Vector2 = Vector2.ZERO
var base_sprite_scale: Vector2 = Vector2.ONE
var _collapse_tween: Tween = null
var contact_damage_cooldown: float = 0.0

# ==============================================================================
# INICIALIZAÇÃO E HOOKS DA BOSSBASE
# ==============================================================================

func _setup_dialogues() -> void:
	dialogos_inicio = [
		{"icone": player_icon, "texto": "Minha mente está pesada... Uma névoa densa que não me deixa raciocinar. É a exaustão cobrando a conta."},
		{"icone": boss_icon, "texto": "Trabalhe mais! Aguente a pressão! Você não tem o direito de parar até se esgotar por completo!"},
		{"icone": player_icon, "texto": "Ignorar meus limites me trouxe a esse colapso. Preciso encontrar clareza e respirar antes de queimar de vez!"}
	]

	dialogos_vitoria = [
		{"icone": player_icon, "texto": "A névoa mental começou a dissipar... Meu corpo finalmente pôde descansar."},
		{"icone": boss_icon, "texto": "O fogo consumiu tudo... Restou apenas o cansaço e as cinzas..."},
		{"icone": player_icon, "texto": "Recuperar-se do esgotamento é um processo, mas aprendi a respeitar meus próprios limites."}
	]

func _process_contact_damage(delta: float) -> void:
	if contact_damage_cooldown > 0.0:
		contact_damage_cooldown -= delta
		return

	if not damage_area or current_state in [State.EXHAUSTED, State.DEATH]:
		return

	for body in damage_area.get_overlapping_bodies():
		if body != self and body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(attack_value, global_position)
			contact_damage_cooldown = 1.2
			break

func _custom_ready() -> void:
	if sprite:
		base_sprite_pos = sprite.position
		base_sprite_scale = sprite.scale

	if not is_instance_valid(player):
		var heroes: Array[Node] = get_tree().get_nodes_in_group("player")
		if not heroes.is_empty():
			player = heroes[0]
		elif get_parent():
			player = get_parent().get_node_or_null("Heroi")

	if decision_timer:
		if not decision_timer.timeout.is_connected(_on_decision_timer_timeout):
			decision_timer.timeout.connect(_on_decision_timer_timeout)
		decision_timer.start(randf_range(1.5, 3.0))

	if exhaustion_beam:
		exhaustion_beam.visible = false
	if beam_soot_particles:
		beam_soot_particles.emitting = false


func _apply_dynamic_difficulty(life_percent: float) -> void:
	current_life_percent = life_percent

	if life_percent < 0.4:
		speed = 185.0
	elif life_percent < 0.7:
		speed = 165.0

	if current_health <= 0 or _is_boss_dead():
		return

	if not phase_two_collapse_triggered and life_percent <= core_collapse_hp_threshold:
		phase_two_collapse_triggered = true

		if current_state in [State.IDLE, State.RUN]:
			if decision_timer:
				decision_timer.stop()
			is_in_knockback = false
			current_state = State.CORE_COLLAPSE_PREP
			execute_attack_sequence()
		else:
			pending_guaranteed_collapse = true


func _can_receive_knockback() -> bool:
	return current_state not in KNOCKBACK_IMMUNE_STATES


func take_damage(amount: int, attacker_pos: Vector2 = Vector2.ZERO) -> void:
	var final_amount: int = amount
	if current_state == State.EXHAUSTED:
		final_amount = maxi(1, roundi(amount * exhausted_damage_multiplier))

	var prev_health: int = current_health
	super.take_damage(final_amount, attacker_pos)
	var actual_damage: int = maxi(0, prev_health - current_health)

	if current_state == State.EXHAUSTION_BEAM and current_health > 0 and not is_dead:
		beam_damage_taken += actual_damage
		if beam_damage_taken >= beam_break_damage_threshold:
			_break_exhaustion_beam(true)


func flip_sprite(dir: float) -> void:
	if dir == 0.0:
		return
	sprite.flip_h = (dir < 0.0)
	if damage_collision:
		damage_collision.position.x = -absf(damage_collision.position.x) if dir < 0.0 else absf(damage_collision.position.x)
	if shoot_point:
		shoot_point.position.x = -absf(shoot_point.position.x) if dir < 0.0 else absf(shoot_point.position.x)


func _on_death() -> void:
	current_state = State.DEATH
	if decision_timer:
		decision_timer.stop()
	_cleanup_exhaustion_beam()
	_stop_collapse_effects()
	if damage_collision:
		damage_collision.set_deferred("disabled", true)
	get_tree().call_group("burnout_hazards", "force_cleanup")


func _exit_tree() -> void:
	_cleanup_exhaustion_beam()


# ==============================================================================
# LOOP DE FÍSICA E MOVIMENTAÇÃO
# ==============================================================================

func _physics_process(delta: float) -> void:
	if _is_boss_dead():
		return

	if is_in_knockback:
		move_and_slide()
		return

	_apply_gravity(delta)
	_process_contact_damage(delta)
	_process_state_movement(delta)
	move_and_slide()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta


func _process_state_movement(delta: float) -> void:
	if current_state in DECELERATING_STATES:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		return

	match current_state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, speed)
			anim.play("idle")

		State.CORE_COLLAPSE_PREP:
			velocity.x = 0.0
			if sprite:
				sprite.position = base_sprite_pos + Vector2(
					randf_range(-collapse_shake_intensity, collapse_shake_intensity),
					randf_range(-collapse_shake_intensity * 0.5, collapse_shake_intensity * 0.5)
				)

		State.EXHAUSTED:
			velocity.x = 0.0

		State.EXHAUSTION_BEAM_PREP:
			velocity.x = move_toward(velocity.x, 0.0, speed)
			if is_instance_valid(player):
				_face_player()
				_update_exhaustion_beam_visual(true, global_position.distance_to(player.global_position))

		State.EXHAUSTION_BEAM:
			_process_exhaustion_beam(delta)

		State.RUN:
			_process_run_state()


func _process_exhaustion_beam(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, speed)

	if not _is_player_alive():
		_break_exhaustion_beam(false)
		return

	var dist: float = global_position.distance_to(player.global_position)
	if dist > beam_max_distance:
		_break_exhaustion_beam(false)
		return

	beam_elapsed += delta
	if beam_max_duration > 0.0 and beam_elapsed >= beam_max_duration:
		_break_exhaustion_beam(false)
		return

	_face_player()
	_update_exhaustion_beam_visual(false, dist)

	beam_drain_timer -= delta
	if beam_drain_timer <= 0.0:
		beam_drain_timer = beam_drain_interval
		if player.has_method("apply_drain_damage"):
			player.apply_drain_damage(beam_drain_damage)
		elif player.has_method("take_damage"):
			player.take_damage(beam_drain_damage, global_position)


func _process_run_state() -> void:
	if is_on_wall():
		walk_direction *= -1
		flip_sprite(walk_direction)
	elif is_instance_valid(player):
		var diff_x: float = player.global_position.x - global_position.x
		if absf(diff_x) > 12.0:
			walk_direction = int(signf(diff_x))
			flip_sprite(walk_direction)

	velocity.x = walk_direction * speed
	anim.play("idle")


# ==============================================================================
# MÁQUINA DE DECISÃO E SEQUÊNCIAS DE ATAQUE
# ==============================================================================

func _on_decision_timer_timeout() -> void:
	if current_state not in [State.IDLE, State.RUN]:
		return
	decision_timer.stop()

	var choices: Array[State] = [
		State.RUN,
		State.SOOT_CLOUD,
		State.EMBER_RAIN_PREP,
		State.EXHAUSTION_BEAM_PREP,
		State.CORE_COLLAPSE_PREP,
		State.BURST_SHOT
	]

	if not _is_player_alive() or global_position.distance_to(player.global_position) > beam_cast_range:
		choices.erase(State.EXHAUSTION_BEAM_PREP)

	if choices.size() > 1:
		if current_life_percent > ember_rain_hp_threshold:
			choices.erase(State.EMBER_RAIN_PREP)

		if (
			not phase_two_collapse_triggered
			or current_life_percent >= core_collapse_hp_threshold
			or attacks_since_collapse < min_attacks_between_collapses
		):
			choices.erase(State.CORE_COLLAPSE_PREP)

	if choices.is_empty():
		current_state = State.RUN
		decision_timer.start(0.5)
		return

	if choices.size() > 1:
		var filtered: Array[State] = choices.filter(func(s: State) -> bool: return s != last_attack)
		if not filtered.is_empty():
			choices = filtered

	current_state = choices.pick_random()
	last_attack = current_state
	execute_attack_sequence()


func execute_attack_sequence() -> void:
	match current_state:
		State.RUN:
			if decision_timer:
				decision_timer.start(randf_range(1.8, 3.0))
		State.SOOT_CLOUD:
			await _execute_soot_cloud()
		State.EMBER_RAIN_PREP:
			await _execute_ember_rain_prep()
		State.EMBER_RAIN:
			await _execute_ember_rain()
		State.CORE_COLLAPSE_PREP:
			await _execute_core_collapse_prep()
		State.EXHAUSTED:
			await _execute_exhausted()
		State.EXHAUSTION_BEAM_PREP:
			await _execute_exhaustion_beam_prep()
		State.BURST_SHOT:
			await _execute_burst_shot()


func _finish_attack_sequence(finished_attack: State) -> void:
	if current_health <= 0 or _is_boss_dead():
		return

	if pending_guaranteed_collapse:
		_trigger_guaranteed_collapse()
		return

	attacks_since_collapse += 1
	last_attack = finished_attack
	current_state = State.IDLE
	_restart_decision_timer()


# --- ATAQUE 1: NÉVOA DE FULIGEM ---

func _execute_soot_cloud() -> void:
	velocity.x = 0.0
	spawn_soot_cloud()

	await get_tree().create_timer(1.2, false).timeout
	if not _is_boss_dead():
		_finish_attack_sequence(State.SOOT_CLOUD)


func spawn_soot_cloud() -> void:
	if not soot_cloud_scene:
		return

	var spawn_pos: Vector2 = global_position
	if is_instance_valid(player):
		var clamped_x: float = clampf(player.global_position.x, arena_min_x, arena_max_x)
		spawn_pos = Vector2(clamped_x, global_position.y)

	var cloud: Node = soot_cloud_scene.instantiate()
	if get_parent() is Node2D:
		cloud.position = get_parent().to_local(spawn_pos)
	else:
		cloud.global_position = spawn_pos

	get_parent().add_child(cloud)


# --- ATAQUE 2: CHUVA DE BRASAS ---

func _execute_ember_rain_prep() -> void:
	velocity.x = 0.0
	_face_player()
	_set_core_overheat(true)
	anim.play("ember_rain_prep")

	await get_tree().create_timer(ember_prep_time, false).timeout
	if _is_boss_dead():
		return

	current_state = State.EMBER_RAIN
	execute_attack_sequence()


func _execute_ember_rain() -> void:
	velocity.x = 0.0

	await _spawn_ember_rain()
	if _is_boss_dead():
		return

	_set_core_overheat(false)
	await get_tree().create_timer(0.4, false).timeout
	if not _is_boss_dead():
		_finish_attack_sequence(State.EMBER_RAIN_PREP)


func _spawn_ember_rain() -> void:
	var base_spawn_pos: Vector2 = shoot_point.global_position if shoot_point else global_position + Vector2(0.0, -30.0)
	var fallback_ground_y: float = _get_ground_y(global_position.x)
	var targets: Array[Vector2] = _generate_ember_targets(ember_count, fallback_ground_y)

	for target_pos in targets:
		if _is_boss_dead():
			return

		target_pos.y = _get_ground_y(target_pos.x)

		var puddle: Node = fire_puddle_scene.instantiate()
		get_parent().add_child(puddle)
		if puddle.has_method("setup_telegraph"):
			puddle.setup_telegraph(target_pos, ember_flight_time)

		var ember: Node = ember_scene.instantiate()
		get_parent().add_child(ember)
		var launch_origin: Vector2 = base_spawn_pos + Vector2(randf_range(-12.0, 12.0), randf_range(-8.0, 8.0))
		if ember.has_method("setup"):
			ember.setup(launch_origin, target_pos, ember_flight_time, ember_arc_height, puddle)

		await get_tree().create_timer(ember_spawn_interval, false).timeout


func _generate_ember_targets(count: int, ground_y: float) -> Array[Vector2]:
	var targets: Array[Vector2] = []
	var margin: float = 40.0
	var min_x: float = arena_min_x + margin
	var max_x: float = arena_max_x - margin

	if is_instance_valid(player):
		var player_x: float = clampf(player.global_position.x + randf_range(-25.0, 25.0), min_x, max_x)
		targets.append(Vector2(player_x, ground_y))

	var attempts: int = 0
	while targets.size() < count and attempts < count * 15:
		attempts += 1
		var candidate_x: float = randf_range(min_x, max_x)
		var too_close: bool = false
		for pos in targets:
			if absf(pos.x - candidate_x) < ember_min_spacing:
				too_close = true
				break
		if not too_close:
			targets.append(Vector2(candidate_x, ground_y))

	targets.shuffle()
	return targets


func _get_ground_y(target_x: float) -> float:
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var from: Vector2 = Vector2(target_x, global_position.y - 50.0)
	var to: Vector2 = Vector2(target_x, global_position.y + 500.0)
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to, ground_collision_mask)

	var exclusions: Array[RID] = [get_rid()]
	if is_instance_valid(player) and player is CollisionObject2D:
		exclusions.append(player.get_rid())
	query.exclude = exclusions

	var result: Dictionary = space_state.intersect_ray(query)
	if not result.is_empty():
		return result.position.y
	return global_position.y + ground_offset_y


func _set_core_overheat(active: bool) -> void:
	if core_particles:
		core_particles.emitting = active
	if sprite:
		var target_color: Color = Color(1.5, 0.45, 0.25, 1.0) if active else Color.WHITE
		var tween: Tween = create_tween()
		tween.tween_property(sprite, "modulate", target_color, 0.25)


# --- ATAQUE 3: COLAPSO DO NÚCLEO ---

func _execute_core_collapse_prep() -> void:
	is_in_knockback = false
	velocity.x = 0.0
	last_attack = State.CORE_COLLAPSE_PREP
	attacks_since_collapse = 0

	_face_player()
	if anim and anim.has_animation("idle"):
		anim.play("idle")

	_start_overheat_fakeout_fx()

	await get_tree().create_timer(collapse_prep_duration, false).timeout
	if _is_boss_dead():
		return

	current_state = State.EXHAUSTED
	execute_attack_sequence()


func _execute_exhausted() -> void:
	velocity.x = 0.0
	_stop_collapse_effects()

	if collapse_smoke:
		collapse_smoke.restart()
		collapse_smoke.emitting = true

	if damage_collision:
		damage_collision.set_deferred("disabled", true)

	anim.play("collapse")
	_play_exhausted_visual()

	var stun_duration: float = randf_range(exhausted_min_duration, exhausted_max_duration)
	await get_tree().create_timer(stun_duration, false).timeout
	if _is_boss_dead():
		return

	_restore_from_exhausted()
	last_attack = State.CORE_COLLAPSE_PREP
	attacks_since_collapse = 0
	current_state = State.IDLE
	_restart_decision_timer()


func _start_overheat_fakeout_fx() -> void:
	if core_particles:
		core_particles.emitting = true

	if _collapse_tween and _collapse_tween.is_valid():
		_collapse_tween.kill()

	if sprite:
		_collapse_tween = create_tween().set_loops()
		_collapse_tween.tween_property(sprite, "modulate", Color(1.0, 0.35, 0.15, 1.0), 0.08)
		_collapse_tween.tween_property(sprite, "modulate", Color(1.0, 0.92, 0.45, 1.0), 0.08)


func _play_exhausted_visual() -> void:
	if not sprite:
		return
	if _collapse_tween and _collapse_tween.is_valid():
		_collapse_tween.kill()
	_collapse_tween = create_tween().set_parallel(true)
	_collapse_tween.tween_property(sprite, "modulate", Color(0.42, 0.42, 0.48, 1.0), 0.25)


func _stop_collapse_effects() -> void:
	if _collapse_tween and _collapse_tween.is_valid():
		_collapse_tween.kill()
	if core_particles:
		core_particles.emitting = false
	if sprite:
		sprite.position = base_sprite_pos
		sprite.scale = base_sprite_scale
		sprite.modulate = Color.WHITE


func _restore_from_exhausted() -> void:
	_stop_collapse_effects()
	if damage_collision and not _is_boss_dead():
		damage_collision.set_deferred("disabled", false)


# --- ATAQUE 4: FEIXE DE EXAUSTÃO ---

func _execute_exhaustion_beam_prep() -> void:
	velocity.x = 0.0
	_play_animation_with_fallback("exhaustion_beam_prep", "attack")

	await get_tree().create_timer(beam_prep_time, false).timeout
	if current_state != State.EXHAUSTION_BEAM_PREP or _is_boss_dead():
		_cleanup_exhaustion_beam()
		return

	if not _is_player_alive() or global_position.distance_to(player.global_position) > beam_max_distance:
		_cleanup_exhaustion_beam()
		if pending_guaranteed_collapse:
			_trigger_guaranteed_collapse()
		else:
			last_attack = State.EXHAUSTION_BEAM_PREP
			current_state = State.IDLE
			_restart_decision_timer()
		return

	_start_exhaustion_beam()


func _start_exhaustion_beam() -> void:
	current_state = State.EXHAUSTION_BEAM
	last_attack = State.EXHAUSTION_BEAM_PREP
	beam_damage_taken = 0
	beam_elapsed = 0.0
	beam_drain_timer = beam_drain_interval

	if anim and anim.has_animation("exhaustion_beam"):
		anim.play("exhaustion_beam")

	if is_instance_valid(player):
		if player.has_method("set_cooldown_multiplier"):
			player.set_cooldown_multiplier(beam_cooldown_multiplier)
		_update_exhaustion_beam_visual(false, global_position.distance_to(player.global_position))


func _update_exhaustion_beam_visual(is_telegraph: bool, current_dist: float) -> void:
	if not exhaustion_beam or not is_instance_valid(player):
		return

	exhaustion_beam.visible = true
	var start_global: Vector2 = shoot_point.global_position if shoot_point else global_position
	var end_global: Vector2 = player.global_position + player_chest_offset
	var dir: Vector2 = start_global.direction_to(end_global)
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var time_sec: float = Time.get_ticks_msec() * 0.001

	exhaustion_beam.clear_points()
	var segs: int = maxi(beam_segments, 2)
	for i in range(segs + 1):
		var t: float = float(i) / float(segs)
		var point_global: Vector2 = start_global.lerp(end_global, t)
		if not is_telegraph:
			var wave: float = sin(t * TAU * 2.0 - time_sec * 14.0) * sin(t * PI) * beam_wave_amplitude
			point_global += perp * wave
		exhaustion_beam.add_point(exhaustion_beam.to_local(point_global))

	if is_telegraph:
		exhaustion_beam.width = 3.0
		exhaustion_beam.default_color = Color(0.75, 0.75, 0.8, 0.55)
		if beam_soot_particles:
			beam_soot_particles.emitting = false
	else:
		var stretch_ratio: float = clampf(current_dist / maxf(beam_max_distance, 1.0), 0.0, 1.0)
		exhaustion_beam.width = lerpf(13.0, 6.5, stretch_ratio * 0.65) + sin(time_sec * 20.0) * 1.1
		exhaustion_beam.default_color = Color(0.45, 0.45, 0.5, 0.92).lerp(Color(0.82, 0.82, 0.88, 0.65), stretch_ratio)
		if beam_soot_particles:
			beam_soot_particles.global_position = end_global
			beam_soot_particles.emitting = true


func _break_exhaustion_beam(_broken_by_damage: bool) -> void:
	if current_state != State.EXHAUSTION_BEAM:
		return

	_cleanup_exhaustion_beam()
	_finish_attack_sequence(State.EXHAUSTION_BEAM_PREP)


func _cleanup_exhaustion_beam() -> void:
	if exhaustion_beam:
		exhaustion_beam.visible = false
		exhaustion_beam.clear_points()
	if beam_soot_particles:
		beam_soot_particles.emitting = false
	if is_instance_valid(player) and player.has_method("set_cooldown_multiplier"):
		player.set_cooldown_multiplier(1.0)


# --- ATAQUE 5: RAJADA DE BRASAS ---

func _execute_burst_shot() -> void:
	velocity.x = 0.0
	_face_player()
	anim.play("ember_rain_prep")

	await get_tree().create_timer(burst_prep_time, false).timeout
	if current_state == State.DEATH:
		return

	await fire_burst_shot()
	if current_state == State.DEATH:
		return

	await get_tree().create_timer(0.35, false).timeout
	if current_state != State.DEATH:
		_finish_attack_sequence(State.BURST_SHOT)


func fire_burst_shot() -> void:
	if not burst_projectile_scene or not is_instance_valid(player):
		return

	var count: int = randi_range(burst_count_min, burst_count_max)
	var spread_rad: float = deg_to_rad(burst_spread_degrees)

	_face_player()

	var spawn_pos: Vector2 = shoot_point.global_position if shoot_point else global_position
	var dir_base: Vector2 = spawn_pos.direction_to(player.global_position)

	for i in range(count):
		if current_state == State.DEATH or not is_instance_valid(player):
			return

		var shot_dir: Vector2 = dir_base.rotated(randf_range(-spread_rad, spread_rad))
		var proj: Node = burst_projectile_scene.instantiate()
		get_parent().add_child(proj)
		proj.global_position = spawn_pos

		if proj.has_method("setup"):
			proj.setup(shot_dir, burst_projectile_speed)

		if i < count - 1:
			await get_tree().create_timer(burst_fire_interval, false).timeout


# ==============================================================================
# UTILITÁRIOS INTERNOS
# ==============================================================================

func _trigger_guaranteed_collapse() -> void:
	pending_guaranteed_collapse = false
	current_state = State.CORE_COLLAPSE_PREP
	execute_attack_sequence()


func _restart_decision_timer() -> void:
	if decision_timer:
		decision_timer.start(maxf(attack_cooldown, 0.5))


func _face_player() -> void:
	if is_instance_valid(player):
		flip_sprite(player.global_position.x - global_position.x)


func _is_boss_dead() -> bool:
	return current_state == State.DEATH or is_dead


func _is_player_alive() -> bool:
	return is_instance_valid(player) and player.get("is_dead") != true


func _play_animation_with_fallback(primary: String, fallback: String) -> void:
	if not anim:
		return
	if anim.has_animation(primary):
		anim.play(primary)
	elif anim.has_animation(fallback):
		anim.play(fallback)
