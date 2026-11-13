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

@export_group("Arena Bounds")
@export var arena_min_x: float = 120.0
@export var arena_max_x: float = 1160.0

@export_group("Ataques")
@export var soot_cloud_scene: PackedScene

@export_group("Ataque: Rajada de Brasas")
@export var burst_projectile_scene: PackedScene
@export var burst_count_min: int = 4
@export var burst_count_max: int = 5
@export var burst_fire_interval: float = 0.3 # Tempo entre cada tiro
@export var burst_spread_degrees: float = 6.0 # Leve imprecisão/recuo por tiro
@export var burst_projectile_speed: float = 480.0
@export var burst_prep_time: float = 0.45

@export_group("Ataque: Feixe de Exaustão")
@export var beam_prep_time: float = 0.65
@export var beam_cast_range: float = 420.0 # Distância máxima para iniciar o ataque
@export var beam_max_distance: float = 540.0 # max_dist para quebrar o feixe afastando-se
@export var beam_break_damage_threshold: int = 40 # Dano necessário no boss para quebrar o feixe
@export var beam_cooldown_multiplier: float = 2.0
@export var beam_drain_damage: int = 2
@export var beam_drain_interval: float = 0.5
@export var beam_max_duration: float = 8.0 # Use 0.0 para não limitar por tempo
@export var beam_segments: int = 12
@export var beam_wave_amplitude: float = 5.5
@export var player_chest_offset: Vector2 = Vector2.ZERO # Ajuste ex: Vector2(0, -16) se a origem do herói for nos pés

@onready var exhaustion_beam: Line2D = get_node_or_null("ExhaustionBeam")
@onready var beam_soot_particles: CPUParticles2D = get_node_or_null("BeamSootParticles")

var beam_damage_taken: int = 0
var beam_drain_timer: float = 0.0
var beam_elapsed: float = 0.0

@export_group("Ataque: Colapso do Núcleo")
@export var collapse_prep_duration: float = 2.0
@export var exhausted_min_duration: float = 3.0
@export var exhausted_max_duration: float = 4.0
@export var collapse_shake_intensity: float = 4.5
@export var exhausted_damage_multiplier: float = 1.5 # Use 1.0 se não quiser bônus de dano na punição
@export_range(0.0, 1.0, 0.05) var core_collapse_hp_threshold: float = 0.5 # Coloque 1.0 para testar antes dos 50% HP
@export_range(0.0, 1.0, 0.05) var collapse_occasional_chance: float = 0.20 # 20% de chance abaixo de 50% HP
@export var min_attacks_between_collapses: int = 2 # Exige ao menos 2 outros golpes entre colapsos

var phase_two_collapse_triggered: bool = false
var pending_guaranteed_collapse: bool = false
var attacks_since_collapse: int = 0

@onready var collapse_sparks: CPUParticles2D = get_node_or_null("SparksParticles")
@onready var collapse_smoke: CPUParticles2D = get_node_or_null("SmokeParticles")

var base_sprite_pos: Vector2 = Vector2.ZERO
var base_sprite_scale: Vector2 = Vector2.ONE
var _collapse_tween: Tween = null

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
@export_range(0.0, 1.0, 0.05) var ember_rain_hp_threshold: float = 1.0 # Deixe 1.0 para testar logo ou 0.5 para Fase 2

var current_life_percent: float = 1.0
var last_attack: State = State.IDLE

@onready var core_particles: CPUParticles2D = get_node_or_null("SparksParticles")

var current_state: State = State.IDLE
var walk_direction: int = -1
var contact_damage_cooldown: float = 0.0

@onready var shoot_point: Marker2D = get_node_or_null("PontoDeTiro")
@onready var body_collision: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var damage_collision: CollisionShape2D = get_node_or_null("DamageArea/CollisionShape2D")


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


func _custom_ready() -> void:
	if sprite:
		base_sprite_pos = sprite.position
		base_sprite_scale = sprite.scale

	if not is_instance_valid(player):
		var heroes = get_tree().get_nodes_in_group("player")
		if heroes.size() > 0:
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


func _physics_process(delta: float) -> void:
	if current_state == State.DEATH or is_dead:
		return

	if is_in_knockback:
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y += gravity * delta

	if contact_damage_cooldown > 0.0:
		contact_damage_cooldown -= delta

	match current_state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, speed)
			anim.play("idle")
		State.SOOT_CLOUD, State.EMBER_RAIN_PREP, State.EMBER_RAIN, State.BURST_SHOT:
			velocity.x = move_toward(velocity.x, 0.0, speed)
			
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
				flip_sprite(signf(player.global_position.x - global_position.x))
				_update_exhaustion_beam_visual(true, global_position.distance_to(player.global_position))

		State.EXHAUSTION_BEAM:
			velocity.x = move_toward(velocity.x, 0.0, speed)
			if not is_instance_valid(player) or player.get("is_dead") == true:
				_break_exhaustion_beam(false)
			else:
				var dist: float = global_position.distance_to(player.global_position)
				if dist > beam_max_distance:
					_break_exhaustion_beam(false)
				else:
					beam_elapsed += delta
					if beam_max_duration > 0.0 and beam_elapsed >= beam_max_duration:
						_break_exhaustion_beam(false)
					else:
						flip_sprite(signf(player.global_position.x - global_position.x))
						_update_exhaustion_beam_visual(false, dist)
						beam_drain_timer -= delta
						if beam_drain_timer <= 0.0:
							beam_drain_timer = beam_drain_interval
							if player.has_method("apply_drain_damage"):
								player.apply_drain_damage(beam_drain_damage)
							elif player.has_method("take_damage"):
								player.take_damage(beam_drain_damage, global_position)

		State.RUN:
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


	move_and_slide()


func execute_attack_sequence() -> void:
	match current_state:
		State.RUN:
			if decision_timer:
				decision_timer.start(randf_range(1.8, 3.0))
		State.SOOT_CLOUD:
			velocity.x = 0.0
			spawn_soot_cloud()

			await get_tree().create_timer(1.2, false).timeout
			if current_state == State.DEATH or is_dead:
				return
			_finish_attack_sequence(State.SOOT_CLOUD)

		State.EMBER_RAIN_PREP:
			velocity.x = 0.0
			if is_instance_valid(player):
				flip_sprite(player.global_position.x - global_position.x)

			_set_core_overheat(true)
			anim.play("ember_rain_prep")


			await get_tree().create_timer(ember_prep_time, false).timeout
			if current_state == State.DEATH or is_dead:
				return

			current_state = State.EMBER_RAIN
			execute_attack_sequence()

		State.EMBER_RAIN:
			velocity.x = 0.0


			await _spawn_ember_rain()
			if current_state == State.DEATH or is_dead:
				return

			_set_core_overheat(false)
			await get_tree().create_timer(0.4, false).timeout
			if current_state == State.DEATH or is_dead:
				return

			_finish_attack_sequence(State.EMBER_RAIN_PREP)

		State.CORE_COLLAPSE_PREP:
			is_in_knockback = false
			velocity.x = 0.0
			last_attack = State.CORE_COLLAPSE_PREP
			attacks_since_collapse = 0

			if is_instance_valid(player):
				flip_sprite(player.global_position.x - global_position.x)
				
			if anim and anim.has_animation("idle"):
				anim.play("idle")
				
			_start_overheat_fakeout_fx()
			
			await get_tree().create_timer(collapse_prep_duration, false).timeout
			if current_state == State.DEATH or is_dead:
				return

			current_state = State.EXHAUSTED
			execute_attack_sequence()

		State.EXHAUSTED:
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
			if current_state == State.DEATH or is_dead:
				return

			_restore_from_exhausted()
			last_attack = State.CORE_COLLAPSE_PREP
			attacks_since_collapse = 0
			current_state = State.IDLE

			if decision_timer:
				decision_timer.start(maxf(attack_cooldown, 0.5))

		State.EXHAUSTION_BEAM_PREP:
			velocity.x = 0.0
			if anim and anim.has_animation("exhaustion_beam_prep"):
				anim.play("exhaustion_beam_prep")
			elif anim and anim.has_animation("attack"):
				anim.play("attack")

			await get_tree().create_timer(beam_prep_time, false).timeout
			if current_state != State.EXHAUSTION_BEAM_PREP or current_state == State.DEATH or is_dead:
				_cleanup_exhaustion_beam()
				return

			if not is_instance_valid(player) or player.get("is_dead") == true or global_position.distance_to(player.global_position) > beam_max_distance:
				_cleanup_exhaustion_beam()
				if pending_guaranteed_collapse:
					pending_guaranteed_collapse = false
					current_state = State.CORE_COLLAPSE_PREP
					execute_attack_sequence()
				else:
					last_attack = State.EXHAUSTION_BEAM_PREP
					current_state = State.IDLE
					if decision_timer:
						decision_timer.start(maxf(attack_cooldown, 0.5))
				return

			_start_exhaustion_beam()
		State.BURST_SHOT:
			velocity.x = 0.0
			if is_instance_valid(player):
				flip_sprite(player.global_position.x - global_position.x)
			
			anim.play("ember_rain_prep")
			
			await get_tree().create_timer(burst_prep_time, false).timeout
			if current_state == State.DEATH:
				return
			
			await fire_burst_shot()
			if current_state == State.DEATH:
				return
			
			await get_tree().create_timer(0.35, false).timeout
			if current_state == State.DEATH:
				return
			
			_finish_attack_sequence(State.BURST_SHOT)

func fire_burst_shot() -> void:
	if not burst_projectile_scene:
		return
	
	var count: int = randi_range(burst_count_min, burst_count_max)
	var spread_rad: float = deg_to_rad(burst_spread_degrees)
	
	# Mantém o Boss virado para o jogador durante a rajada
	flip_sprite(player.global_position.x - global_position.x)
		
	var spawn_pos: Vector2 = shoot_point.global_position if shoot_point else global_position
	var dir_base: Vector2 = spawn_pos.direction_to(player.global_position)
	
	for i in range(count):
		if current_state == State.DEATH or not is_instance_valid(player):
			return
		
		
		var random_offset: float = randf_range(-spread_rad, spread_rad)
		var shot_dir: Vector2 = dir_base.rotated(random_offset)
		
		var proj = burst_projectile_scene.instantiate()
		get_parent().add_child(proj)
		proj.global_position = spawn_pos
		
		if proj.has_method("setup"):
			proj.setup(shot_dir, burst_projectile_speed)
		
		if i < count - 1:
			await get_tree().create_timer(burst_fire_interval, false).timeout
			

func _finish_attack_sequence(finished_attack: State) -> void:
	if current_health <= 0 or current_state == State.DEATH or is_dead:
		return

	# Se o Boss bateu 50% de HP durante o ataque que acabou de terminar, colapsa agora
	if pending_guaranteed_collapse:
		pending_guaranteed_collapse = false
		current_state = State.CORE_COLLAPSE_PREP
		execute_attack_sequence()
		return

	attacks_since_collapse += 1
	last_attack = finished_attack
	current_state = State.IDLE

	if decision_timer:
		decision_timer.start(maxf(attack_cooldown, 0.5))


func _start_overheat_fakeout_fx() -> void:
	if core_particles:
		core_particles.emitting = true
	if collapse_sparks:
		collapse_sparks.emitting = true

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
	if collapse_sparks:
		collapse_sparks.emitting = false
	if sprite:
		sprite.position = base_sprite_pos
		sprite.scale = base_sprite_scale
		sprite.modulate = Color.WHITE


func _restore_from_exhausted() -> void:
	_stop_collapse_effects()
	if damage_collision and current_state != State.DEATH and not is_dead:
		damage_collision.set_deferred("disabled", false)


func _on_decision_timer_timeout() -> void:
	if current_state not in [State.IDLE, State.RUN]:
		return
	decision_timer.stop()

	# Comente com # os ataques que você não quiser testar
	var choices: Array[State] = [
		State.RUN,
		State.SOOT_CLOUD,
		State.EMBER_RAIN_PREP,
		State.EXHAUSTION_BEAM_PREP,
		State.CORE_COLLAPSE_PREP,
		State.BURST_SHOT
	]

	# Só usa o Feixe se o jogador estiver dentro do alcance
	if (
		not is_instance_valid(player)
		or player.get("is_dead") == true
		or global_position.distance_to(player.global_position) > beam_cast_range
	):
		choices.erase(State.EXHAUSTION_BEAM_PREP)

	# Aplica as travas de vida/intervalo quando houver outros ataques ativos
	if choices.size() > 1:
		if current_life_percent > ember_rain_hp_threshold:
			choices.erase(State.EMBER_RAIN_PREP)

		if (
			not phase_two_collapse_triggered
			or current_life_percent >= core_collapse_hp_threshold
			or attacks_since_collapse < min_attacks_between_collapses
		):
			choices.erase(State.CORE_COLLAPSE_PREP)

	# Evita erro de array vazio caso só o Feixe esteja ativo com o herói longe
	if choices.is_empty():
		current_state = State.RUN
		decision_timer.start(0.5)
		return

	# Evita repetir o mesmo ataque logo em seguida
	if choices.size() > 1:
		var filtered: Array[State] = choices.filter(func(s): return s != last_attack)
		if not filtered.is_empty():
			choices = filtered

	current_state = choices.pick_random()
	last_attack = current_state
	execute_attack_sequence()


func _spawn_ember_rain() -> void:

	var base_spawn_pos: Vector2 = shoot_point.global_position if shoot_point else global_position + Vector2(0.0, -30.0)
	var fallback_ground_y: float = _get_ground_y(global_position.x)
	var targets: Array[Vector2] = _generate_ember_targets(ember_count, fallback_ground_y)

	for target_pos in targets:
		if current_state == State.DEATH or is_dead:
			return

		target_pos.y = _get_ground_y(target_pos.x)

		# Sempre adiciona na árvore antes de chamar setup() por causa do offset da Arena
		var puddle := fire_puddle_scene.instantiate()
		get_parent().add_child(puddle)
		if puddle.has_method("setup_telegraph"):
			puddle.setup_telegraph(target_pos, ember_flight_time)

		var ember := ember_scene.instantiate()
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

	# Mira uma brasa próxima ao jogador para forçá-lo a manobrar
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
	var space_state := get_world_2d().direct_space_state
	var from := Vector2(target_x, global_position.y - 50.0)
	var to := Vector2(target_x, global_position.y + 500.0)
	var query := PhysicsRayQueryParameters2D.create(from, to, ground_collision_mask)
	var exclusions: Array[RID] = [get_rid()]
	if is_instance_valid(player) and player is CollisionObject2D:
		exclusions.append(player.get_rid())
	query.exclude = exclusions

	var result := space_state.intersect_ray(query)
	if result:
		return result.position.y
	return global_position.y + ground_offset_y


func _set_core_overheat(active: bool) -> void:
	if core_particles:
		core_particles.emitting = active
	if sprite:
		var target_color: Color = Color(1.5, 0.45, 0.25, 1.0) if active else Color.WHITE
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", target_color, 0.25)


func spawn_soot_cloud() -> void:
	if not soot_cloud_scene:
		return
	var spawn_pos: Vector2 = global_position
	if is_instance_valid(player):
		var clamped_x: float = clampf(player.global_position.x, arena_min_x, arena_max_x)
		spawn_pos = Vector2(clamped_x, global_position.y)

	var cloud = soot_cloud_scene.instantiate()
	if get_parent() is Node2D:
		cloud.position = get_parent().to_local(spawn_pos)
	else:
		cloud.global_position = spawn_pos

	get_parent().add_child(cloud)


func _start_exhaustion_beam() -> void:
	current_state = State.EXHAUSTION_BEAM
	last_attack = State.EXHAUSTION_BEAM_PREP
	beam_damage_taken = 0
	beam_elapsed = 0.0
	beam_drain_timer = beam_drain_interval

	if anim and anim.has_animation("exhaustion_beam"):
		anim.play("exhaustion_beam")

	if is_instance_valid(player) and player.has_method("set_cooldown_multiplier"):
		player.set_cooldown_multiplier(beam_cooldown_multiplier)

	if is_instance_valid(player):
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


func flip_sprite(dir: float) -> void:
	if dir == 0.0:
		return
	sprite.flip_h = (dir < 0.0)
	if damage_collision:
		damage_collision.position.x = -abs(damage_collision.position.x) if dir < 0.0 else abs(damage_collision.position.x)
	if shoot_point:
		shoot_point.position.x = -abs(shoot_point.position.x) if dir < 0.0 else abs(shoot_point.position.x)


func _apply_dynamic_difficulty(life_percent: float) -> void:
	current_life_percent = life_percent

	# Burnout fica mais rápido e agressivo conforme sua vida diminui
	if life_percent < 0.4:
		speed = 185.0
	elif life_percent < 0.7:
		speed = 165.0
	if current_health <= 0 or is_dead or current_state == State.DEATH:
		return

	# Garante 100% de ativação quando atingir <= 50% de HP pela primeira vez
	if not phase_two_collapse_triggered and life_percent <= core_collapse_hp_threshold:
		phase_two_collapse_triggered = true

		if current_state in [State.IDLE, State.RUN]:
			if decision_timer:
				decision_timer.stop()
			is_in_knockback = false
			current_state = State.CORE_COLLAPSE_PREP
			execute_attack_sequence()
		else:
			# Se estiver no meio de outro ataque, engata o colapso logo ao terminar
			pending_guaranteed_collapse = true


func _can_receive_knockback() -> bool:
	return current_state not in [
		State.CORE_COLLAPSE_PREP,
		State.EXHAUSTED,
		State.EXHAUSTION_BEAM_PREP,
		State.EXHAUSTION_BEAM,
		State.BURST_SHOT,
		State.DEATH
	]


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
