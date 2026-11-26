extends BossBase

enum State {
	IDLE,
	RUN,
	THOUGHTS,
	TELEPORT,
	EXPLOSION_PREP,
	EXPLOSION,
	DASH_PREP,
	DASH,
	DEATH
}

# --- CONFIGURAÇÕES EXPORTADAS ---
@export_group("Dificuldade Dinâmica (Cooldowns)")
@export var max_attack_cooldown: float = 1.5
@export var min_attack_cooldown: float = 0.3

@export_group("Ataque: Dash")
@export var stop_distance: float = 160.0
@export var dash_speed: float = 500.0
@export var dash_max_distance: float = 500.0
@export var max_dash_prep: float = 0.7
@export var min_dash_prep: float = 0.1

@export_group("Ataque: Teleporte")
@export var max_teleport_wait: float = 1.0
@export var min_teleport_wait: float = 0.2
@export var min_teleport_distance: float = 250.0
@export var min_player_teleport_distance: float = 110.0

@export_group("Referências Específicas")
@export var projectile_scene: PackedScene
@export var teleport_warning_scene: PackedScene

# --- REFERÊNCIAS DE NÓS (@onready) ---
@onready var ponto_de_tiro: Marker2D = $PontoDeTiro
@onready var particulas: CPUParticles2D = $FireSparks

# --- VARIÁVEIS DE ESTADO ---
var current_state: State = State.IDLE
var current_dash_prep: float = 0.7
var current_teleport_wait: float = 1.0
var dash_direction: int = 0
var dash_distance_left: float = 0.0
var contact_damage_cooldown: float = 0.0


# --- MÉTODOS NATIVOS E VIRTUAIS ---
func _setup_dialogues() -> void:
	dialogos_inicio = [
		{"icone": player_icon, "texto": "Eu consigo fazer isso... Só preciso manter o foco e respirar fundo."},
		{"icone": boss_icon, "texto": "E se tudo der errado? Você não se preparou o suficiente. Desista!"},
		{"icone": player_icon, "texto": "Não vou me render aos pensamentos intrusivos. Vamos resolver isso agora!"}
	]
	dialogos_vitoria = [
		{"icone": player_icon, "texto": "Consegui silenciar a crise... O bombardeio de preocupações diminuiu."},
		{"icone": boss_icon, "texto": "Você venceu desta vez... mas eu sempre posso voltar se você se sobrecarregar."},
		{"icone": player_icon, "texto": "Eu sei. A ansiedade faz parte da vida, mas agora eu tenho ferramentas para não deixar você me paralisar."}
	]


func _custom_ready() -> void:
	current_dash_prep = max_dash_prep
	current_teleport_wait = max_teleport_wait


func _apply_dynamic_difficulty(life_percent: float) -> void:
	attack_cooldown = lerpf(min_attack_cooldown, max_attack_cooldown, life_percent)
	current_dash_prep = lerpf(min_dash_prep, max_dash_prep, life_percent)
	current_teleport_wait = lerpf(min_teleport_wait, max_teleport_wait, life_percent)


func _can_receive_knockback() -> bool:
	return current_state not in [State.TELEPORT, State.DASH, State.DEATH]


func _on_death() -> void:
	current_state = State.DEATH
	if particulas:
		particulas.emitting = false
	if decision_timer:
		decision_timer.stop()


func _physics_process(delta: float) -> void:
	if current_state == State.DEATH:
		_process_death_physics(delta)
		return

	if not is_on_floor() and current_state != State.TELEPORT:
		velocity.y += gravity * delta

	if is_in_knockback:
		move_and_slide()
		return

	_update_contact_damage(delta)
	_process_state_movement(delta)

	if current_state in [State.IDLE, State.RUN, State.DASH]:
		move_and_slide()


# --- FÍSICA E MOVIMENTAÇÃO AUXILIAR ---
func _process_death_physics(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0

	if is_in_knockback:
		move_and_slide()
		return

	velocity.x = 0.0
	move_and_slide()


func _update_contact_damage(delta: float) -> void:
	if contact_damage_cooldown > 0.0:
		contact_damage_cooldown -= delta
	else:
		_process_contact_damage()


func _process_state_movement(delta: float) -> void:
	match current_state:
		State.IDLE:
			if anim and anim.has_animation("idle"):
				anim.play("idle")
			velocity.x = move_toward(velocity.x, 0.0, speed)

		State.RUN:
			_process_run_state()

		State.DASH:
			_process_dash_state(delta)


func _process_run_state() -> void:
	if not player:
		return

	var dist_x: float = absf(player.global_position.x - global_position.x)
	if dist_x > stop_distance:
		var dir: float = signf(player.global_position.x - global_position.x)
		velocity.x = dir * speed
		flip_sprite(dir)
		if anim and anim.has_animation("run"):
			anim.play("run")
	else:
		velocity.x = 0.0
		decision_timer.stop()
		current_state = State.DASH_PREP
		execute_attack_sequence()


func _process_dash_state(delta: float) -> void:
	if anim and anim.has_animation("dash"):
		anim.play("dash")

	var progress_ratio: float = clampf(dash_distance_left / dash_max_distance, 0.0, 1.0)
	var min_dash_speed: float = speed * 0.8
	var current_speed: float = dash_speed

	if progress_ratio < 0.25:
		var ease_t: float = progress_ratio / 0.25
		current_speed = lerpf(min_dash_speed, dash_speed, ease_t)

	var step: float = current_speed * delta
	velocity.x = float(dash_direction) * current_speed
	dash_distance_left -= step

	if is_on_wall() or global_position.x <= 60.0 or global_position.x >= 1220.0:
		dash_distance_left = 0.0

	if dash_distance_left <= 0.0:
		velocity.x = 0.0
		current_state = State.IDLE
		decision_timer.start(attack_cooldown)


func _process_contact_damage() -> void:
	if not damage_area:
		return

	var bodies: Array[Node2D] = damage_area.get_overlapping_bodies()
	for body: Node2D in bodies:
		if body != self and body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(attack_value, global_position)
			contact_damage_cooldown = 1.0
			break


# --- MÁQUINA DE ESTADOS E SEQUÊNCIAS DE ATAQUE ---
func _on_decision_timer_timeout() -> void:
	if current_state != State.IDLE and current_state != State.RUN:
		return
	decision_timer.stop()

	var choices: Array[State] = [
		State.RUN,
		State.DASH_PREP,
		State.THOUGHTS,
		State.EXPLOSION_PREP,
		State.TELEPORT
	]
	current_state = choices.pick_random()
	execute_attack_sequence()


func execute_attack_sequence() -> void:
	match current_state:
		State.THOUGHTS:
			await _execute_thoughts_sequence()

		State.RUN:
			if anim and anim.has_animation("run"):
				anim.play("run")
			decision_timer.start(attack_cooldown)

		State.EXPLOSION_PREP:
			await _execute_explosion_sequence()

		State.TELEPORT:
			await _execute_teleport_sequence()

		State.DASH_PREP:
			await _execute_dash_prep_sequence()


func _execute_thoughts_sequence() -> void:
	velocity.x = 0.0
	if player:
		flip_sprite(signf(player.global_position.x - global_position.x))
	if anim and anim.has_animation("prep_projectile"):
		anim.play("prep_projectile")

	await get_tree().create_timer(0.5).timeout
	if current_state == State.DEATH:
		return

	if anim and anim.has_animation("projectile"):
		anim.play("projectile")
	fire_preoccupation()

	if anim:
		await anim.animation_finished
	if current_state == State.DEATH:
		return

	current_state = State.IDLE
	decision_timer.start(attack_cooldown)


func _execute_explosion_sequence() -> void:
	velocity.x = 0.0
	if anim and anim.has_animation("prep_explosion"):
		anim.play("prep_explosion")

	await get_tree().create_timer(0.5).timeout
	if current_state == State.DEATH:
		return

	current_state = State.EXPLOSION
	if anim and anim.has_animation("explosion"):
		anim.play("explosion")
	fire_explosion()

	await get_tree().create_timer(0.4).timeout
	if current_state == State.DEATH:
		return

	current_state = State.IDLE
	decision_timer.start(attack_cooldown)


func _execute_teleport_sequence() -> void:
	velocity = Vector2.ZERO
	if anim and anim.has_animation("explosion"):
		anim.play("explosion")

	await teleport_routine()
	if current_state == State.DEATH:
		return

	current_state = State.IDLE
	decision_timer.start(attack_cooldown)


func _execute_dash_prep_sequence() -> void:
	velocity.x = 0.0
	if player:
		dash_direction = int(signf(player.global_position.x - global_position.x))
		if dash_direction == 0:
			dash_direction = 1
		flip_sprite(float(dash_direction))

	if anim and anim.has_animation("prep_dash"):
		anim.play("prep_dash")

	await get_tree().create_timer(current_dash_prep).timeout
	if current_state == State.DEATH:
		return

	dash_distance_left = dash_max_distance
	current_state = State.DASH


# --- DISPAROS E HABILIDADES ---
func fire_preoccupation() -> void:
	if not projectile_scene or not player:
		return
	var spawn_pos: Vector2 = ponto_de_tiro.global_position if ponto_de_tiro else global_position
	var proj: Node2D = projectile_scene.instantiate()
	get_parent().add_child(proj)
	proj.global_position = spawn_pos
	var angle: float = spawn_pos.direction_to(player.global_position).angle() + randf_range(-0.2, 0.2)
	if proj.has_method("setup"):
		proj.setup(angle, 500.0)


func fire_explosion() -> void:
	if not projectile_scene:
		return
	var spawn_pos: Vector2 = ponto_de_tiro.global_position if ponto_de_tiro else global_position
	var num_projectiles: int = 12
	for i: int in range(num_projectiles):
		var proj: Node2D = projectile_scene.instantiate()
		get_parent().add_child(proj)
		proj.global_position = spawn_pos
		var angle: float = (2.0 * PI / float(num_projectiles)) * float(i)
		if proj.has_method("setup"):
			proj.setup(angle, 300.0)


func teleport_routine() -> void:
	var teleports_done: int = 0
	while teleports_done < 3:
		var target_pos: Vector2 = Vector2.ZERO
		var valid_position: bool = false
		var attempts: int = 0

		while not valid_position and attempts < 30:
			attempts += 1
			var rand_x: float = randf_range(100.0, 1180.0)
			var rand_y: float = randf_range(300.0, 550.0)
			target_pos = Vector2(rand_x, rand_y)
			var far_from_boss: bool = absf(target_pos.x - global_position.x) >= min_teleport_distance
			var far_from_player: bool = true
			if player:
				far_from_player = target_pos.distance_to(player.global_position) >= min_player_teleport_distance
			if far_from_boss and far_from_player:
				valid_position = true

		if teleport_warning_scene:
			var warning: Node2D = teleport_warning_scene.instantiate()
			get_parent().add_child(warning)
			warning.global_position = target_pos

		await get_tree().create_timer(current_teleport_wait, false, false, true).timeout
		if current_state == State.DEATH:
			return
		global_position = target_pos
		teleports_done += 1

		if teleports_done < 3:
			await get_tree().create_timer(0.3, false, false, true).timeout
			if current_state == State.DEATH:
				return
