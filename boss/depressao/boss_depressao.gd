extends BossBase

enum State {
	IDLE,
	RUN,
	PROJECTILE,
	GEISER_PREP,
	GEISER,
	BAD_THOUGHTS_PREP,
	BAD_THOUGHTS,
	DIRECT_ATTACK_PREP,
	DIRECT_ATTACK,
	MINIGAME,
	RAIN,
	DEATH
}

# --- CONFIGURAÇÕES EXPORTADAS ---
@export_group("Referências Externas")
@export var projectile_scene: PackedScene
@export var geiser_scene: PackedScene
@export var tear_scene: PackedScene
@export var minigame_scene: PackedScene
@export var slam_shockwave_scene: PackedScene

@export_group("Ataque Direto")
@export var direct_attack_damage: int = 20
@export var slam_damage: int = 35
@export var punch_forward_impulse: float = 2000.0
@export var walk_duration: float = 2.0

@export_group("Gêiser")
@export var geiser_spacing: float = 235.0
@export var min_geiser_count: int = 1
@export var max_geiser_count: int = 5

@export_group("Chuva de Lágrimas")
@export var rain_drops_count: int = 21
@export var rain_spawn_y: float = -40.0
@export var arena_min_x: float = 80.0
@export var arena_max_x: float = 1200.0

@export_group("Pensamentos Ruins")
@export var rush_speed: float = 650.0
@export var catch_offset_x: float = 80.0
@export var smash_heavy_damage: int = 40

# --- REFERÊNCIAS DE NÓS (@onready) ---
@onready var ponto_de_tiro: Marker2D = get_node_or_null("PontoDeTiro")
@onready var punch_hitbox: Area2D = get_node_or_null("PunchHitbox")

# --- VARIÁVEIS DE ESTADO ---
var current_state: State = State.IDLE
var damage_cooldown: float = 0.0
var walk_direction: int = 1
var direct_attack_stage: int = 1
var current_geiser_count: int = 1
var current_aura_slow: float = 0.8

var rush_direction: int = 0
var rush_duration: float = 0.95
var player_caught: bool = false
var is_applying_aura: bool = false


# --- MÉTODOS NATIVOS E VIRTUAIS ---
func _setup_dialogues() -> void:
	dialogos_inicio = [
		{"icone": player_icon, "texto": "É aquele mesmo peso no peito... Não é dor, é um nada tão profundo que parece engolir qualquer cor ao meu redor."},
		{"icone": boss_icon, "texto": "Aceite o cinza. Tentar resistir só gasta a energia que você já não tem. Não há nada lá fora que valha o esforço."},
		{"icone": player_icon, "texto": "As cores continuam existindo, sou eu que não consigo enxergar agora. E eu me recuso a afundar nesse silêncio!"}
	]
	
	dialogos_vitoria = [
		{"icone": player_icon, "texto": "O peso afrouxou um pouco. O mundo ainda não está colorido, mas finalmente sinto o chão sob os meus pés."},
		{"icone": boss_icon, "texto": "Mesmo me vencendo hoje... você sabe que não é tão fácil se livrar de mim."},
		{"icone": player_icon, "texto": "Eu sei que não é mágica. Mas hoje a paralisia não venceu. E isso já é uma vitória enorme."}
	]


func _apply_dynamic_difficulty(life_percent: float) -> void:
	if life_percent > 0.60:
		current_geiser_count = 3
		direct_attack_stage = 1
	elif life_percent > 0.30:
		current_geiser_count = 5
		direct_attack_stage = 2
	else:
		current_geiser_count = 9
		direct_attack_stage = 3


func _can_receive_knockback() -> bool:
	return current_state not in [State.MINIGAME, State.BAD_THOUGHTS]


func _on_death() -> void:
	current_state = State.DEATH
	if decision_timer:
		decision_timer.stop()


func _physics_process(delta: float) -> void:
	if current_state == State.DEATH:
		return

	if is_in_knockback:
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y += gravity * delta

	if damage_cooldown > 0.0:
		damage_cooldown -= delta

	_process_movement_state()

	if current_state == State.BAD_THOUGHTS and not player_caught:
		_check_bad_thoughts_catch()

	_process_contact_damage()

	if current_state != State.MINIGAME:
		move_and_slide()


# --- FÍSICA E MOVIMENTAÇÃO AUXILIAR ---
func _process_movement_state() -> void:
	match current_state:
		State.IDLE:
			if anim and anim.has_animation("idle"):
				anim.play("idle")
			velocity.x = move_toward(velocity.x, 0.0, speed)

		State.RUN:
			if is_on_wall():
				walk_direction *= -1
				flip_sprite(float(walk_direction))
			velocity.x = float(walk_direction) * speed
			if anim and anim.has_animation("idle"):
				anim.play("idle")

		State.GEISER_PREP, State.GEISER, State.PROJECTILE, State.RAIN, State.MINIGAME, State.DIRECT_ATTACK_PREP:
			velocity.x = 0.0

		State.DIRECT_ATTACK, State.BAD_THOUGHTS:
			pass


func _check_bad_thoughts_catch() -> void:
	var areas_to_check: Array[Area2D] = []
	if damage_area:
		areas_to_check.append(damage_area)
	if punch_hitbox:
		areas_to_check.append(punch_hitbox)

	for area: Area2D in areas_to_check:
		for body: Node2D in area.get_overlapping_bodies():
			if body.is_in_group("player") and body != self and _is_player_catchable(body):
				trigger_thoughts_minigame(body as CharacterBody2D)
				break
		if player_caught:
			break


func _process_contact_damage() -> void:
	if player_caught or current_state in [State.BAD_THOUGHTS_PREP, State.BAD_THOUGHTS, State.MINIGAME]:
		return

	if damage_cooldown <= 0.0 and damage_area:
		for body: Node2D in damage_area.get_overlapping_bodies():
			if body.is_in_group("player") and body != self and body.has_method("take_damage"):
				body.take_damage(attack_value, global_position)
				damage_cooldown = 1.0
				break


# --- MÁQUINA DE ESTADOS E SEQUÊNCIAS ---
func _on_decision_timer_timeout() -> void:
	if current_state != State.IDLE:
		return

	decision_timer.stop()

	var choices: Array[State] = [
		State.GEISER_PREP,
		State.PROJECTILE,
		State.RAIN,
		State.DIRECT_ATTACK_PREP
	]

	var life_percent: float = float(current_health) / float(max_health)
	if life_percent < 0.5:
		choices.append(State.BAD_THOUGHTS_PREP)

	current_state = choices.pick_random()
	execute_attack_sequence()


func execute_attack_sequence() -> void:
	match current_state:
		State.PROJECTILE:
			await _execute_projectile_sequence()

		State.GEISER_PREP:
			await _execute_geiser_prep_sequence()

		State.GEISER:
			await _execute_geiser_sequence()

		State.RAIN:
			await _execute_rain_sequence()

		State.BAD_THOUGHTS_PREP:
			await _execute_bad_thoughts_prep_sequence()

		State.BAD_THOUGHTS:
			await _execute_bad_thoughts_sequence()

		State.DIRECT_ATTACK_PREP:
			await _execute_direct_attack_prep_sequence()

		State.DIRECT_ATTACK:
			velocity.x = 0.0
			await run_direct_attack_combo()


func _execute_projectile_sequence() -> void:
	if player:
		flip_sprite(player.global_position.x - global_position.x)

	velocity.x = 0.0
	if anim and anim.has_animation("prep_throw_projectile"):
		anim.play("prep_throw_projectile")
	await get_tree().create_timer(0.5).timeout
	if current_state == State.DEATH:
		return

	if anim and anim.has_animation("throw_projectile"):
		anim.play("throw_projectile")
	fire_lodo()
	await get_tree().create_timer(0.7).timeout
	if current_state == State.DEATH:
		return
	if anim and anim.has_animation("idle"):
		anim.play("idle")
	await walk_then_idle()


func _execute_geiser_prep_sequence() -> void:
	velocity.x = 0.0
	if anim and anim.has_animation("prep_geiser"):
		anim.play("prep_geiser")

	if player:
		flip_sprite(player.global_position.x - global_position.x)

	await get_tree().create_timer(0.6).timeout
	if current_state == State.DEATH:
		return

	current_state = State.GEISER
	execute_attack_sequence()


func _execute_geiser_sequence() -> void:
	velocity.x = 0.0
	if anim and anim.has_animation("attack_geiser"):
		anim.play("attack_geiser")

	spawn_geiser()

	if anim and anim.is_playing() and anim.current_animation == "attack_geiser":
		await anim.animation_finished
	else:
		await get_tree().create_timer(0.5).timeout

	if current_state == State.DEATH:
		return
	await walk_then_idle()


func _execute_rain_sequence() -> void:
	velocity.x = 0.0
	await start_tear_rain()
	if current_state == State.DEATH:
		return
	await walk_then_idle()


func _execute_bad_thoughts_prep_sequence() -> void:
	velocity.x = 0.0
	if anim and anim.has_animation("prep_rush"):
		anim.play("prep_rush")

	if player:
		rush_direction = signi(int(player.global_position.x - global_position.x))
		flip_sprite(float(rush_direction))

	await get_tree().create_timer(0.4).timeout
	if current_state == State.DEATH:
		return

	player_caught = false
	current_state = State.BAD_THOUGHTS
	execute_attack_sequence()


func _execute_bad_thoughts_sequence() -> void:
	if anim and anim.has_animation("rush"):
		anim.play("rush")
	velocity.x = float(rush_direction) * rush_speed

	var elapsed: float = 0.0
	while elapsed < rush_duration:
		if player_caught or current_state == State.DEATH or is_on_wall():
			break

		var areas_rush: Array[Area2D] = []
		if damage_area:
			areas_rush.append(damage_area)
		if punch_hitbox:
			areas_rush.append(punch_hitbox)

		for a: Area2D in areas_rush:
			for b: Node2D in a.get_overlapping_bodies():
				if b.is_in_group("player") and b != self and _is_player_catchable(b):
					trigger_thoughts_minigame(b as CharacterBody2D)
					break
			if player_caught:
				break

		elapsed += get_physics_process_delta_time()
		await get_tree().physics_frame

	velocity.x = 0.0

	if not player_caught and current_state != State.MINIGAME:
		await get_tree().create_timer(0.3).timeout
		if current_state == State.DEATH:
			return
		await walk_then_idle()


func _execute_direct_attack_prep_sequence() -> void:
	velocity.x = 0.0
	if player:
		flip_sprite(player.global_position.x - global_position.x)

	if anim and anim.has_animation("prep_direct"):
		anim.play("prep_direct")
	await get_tree().create_timer(0.8).timeout
	if current_state == State.DEATH:
		return

	current_state = State.DIRECT_ATTACK
	execute_attack_sequence()


# --- MÉTODOS PÚBLICOS E HABILIDADES DE COMBATE ---
func fire_lodo() -> void:
	if not projectile_scene or not player:
		return

	var spawn_pos: Vector2 = ponto_de_tiro.global_position if ponto_de_tiro else global_position
	var proj: Node2D = projectile_scene.instantiate()

	get_parent().add_child(proj)
	proj.global_position = spawn_pos

	var dir: Vector2 = spawn_pos.direction_to(player.global_position)
	if proj.has_method("setup"):
		proj.setup(dir)


func spawn_geiser() -> void:
	if not geiser_scene or not player:
		return

	var count: int = current_geiser_count
	var center_x: float = player.global_position.x
	var ground_y: float = global_position.y + 10.0

	var offsets: Array[float] = [0.0]
	var step: int = 1
	while offsets.size() < count:
		offsets.append(float(step) * geiser_spacing)
		if offsets.size() < count:
			offsets.append(float(-step) * geiser_spacing)
		step += 1

	for offset: float in offsets:
		var geiser: Node2D = geiser_scene.instantiate()
		get_parent().add_child(geiser)
		geiser.global_position = Vector2(center_x + offset, ground_y)


func start_tear_rain() -> void:
	if anim and anim.has_animation("cast_rain"):
		anim.play("cast_rain")
	if not tear_scene:
		return

	for i: int in range(rain_drops_count):
		if current_state == State.DEATH:
			return

		var drop: Node2D = tear_scene.instantiate()
		var rand_x: float = randf_range(arena_min_x, arena_max_x)
		get_parent().add_child(drop)
		drop.global_position = Vector2(rand_x, rain_spawn_y)

		await get_tree().create_timer(0.2).timeout


func trigger_thoughts_minigame(target_player: CharacterBody2D) -> void:
	player_caught = true
	current_state = State.MINIGAME
	velocity.x = 0.0

	if is_instance_valid(target_player):
		global_position.x = target_player.global_position.x - (float(rush_direction) * catch_offset_x)

	if is_instance_valid(target_player) and target_player.has_method("trap_player"):
		target_player.trap_player()

	if not minigame_scene:
		if is_instance_valid(target_player) and target_player.has_method("release_player"):
			target_player.release_player()
		player_caught = false
		await walk_then_idle()
		return

	var minigame: Node = minigame_scene.instantiate()
	get_parent().add_child(minigame)

	if minigame.has_method("start_minigame"):
		minigame.start_minigame()

	var success: bool = false
	if minigame.has_signal("minigame_resolved"):
		success = await minigame.minigame_resolved
	else:
		await get_tree().create_timer(2.0).timeout

	if is_instance_valid(target_player) and target_player.has_method("release_player"):
		target_player.release_player()

	if not success:
		if is_instance_valid(target_player) and target_player.has_method("take_damage"):
			target_player.take_damage(smash_heavy_damage, global_position)
	else:
		velocity.x = -float(rush_direction) * 250.0

	damage_cooldown = 1.2
	player_caught = false

	if current_state == State.DEATH:
		return

	await walk_then_idle()


func run_direct_attack_combo() -> void:
	if anim and anim.has_animation("attack_direct"):
		anim.play("attack_direct")
	step_forward(punch_forward_impulse, 0.25)
	apply_direct_hit(direct_attack_damage, 0.25)

	if anim and anim.is_playing() and anim.current_animation == "attack_direct":
		await anim.animation_finished
	else:
		await get_tree().create_timer(0.35).timeout

	if current_state == State.DEATH:
		return

	if direct_attack_stage >= 2:
		await get_tree().create_timer(0.2).timeout
		if current_state == State.DEATH:
			return

		if anim and anim.has_animation("attack_direct_2"):
			anim.play("attack_direct_2")
		step_forward(punch_forward_impulse, 0.25)
		apply_direct_hit(direct_attack_damage, 0.25)

		if anim and anim.is_playing() and anim.current_animation == "attack_direct_2":
			await anim.animation_finished
		else:
			await get_tree().create_timer(0.35).timeout
		if current_state == State.DEATH:
			return

	if direct_attack_stage == 3:
		if current_state == State.DEATH:
			return

		await get_tree().create_timer(0.25).timeout
		if anim and anim.has_animation("slam"):
			anim.play("slam")

		step_forward(punch_forward_impulse * 1.3, 0.3)
		apply_direct_hit(slam_damage, 0.3)

		await get_tree().create_timer(0.25).timeout
		spawn_cortina_lodo()

		if anim and anim.is_playing() and anim.current_animation == "slam":
			await anim.animation_finished
		else:
			await get_tree().create_timer(0.4).timeout
		if current_state == State.DEATH:
			return

	await walk_then_idle()


func spawn_cortina_lodo() -> void:
	if not slam_shockwave_scene:
		return

	for dir: int in [-1, 1]:
		var wave: Node2D = slam_shockwave_scene.instantiate()
		get_parent().add_child(wave)
		wave.global_position = Vector2(global_position.x + (float(dir) * 40.0), global_position.y + 10.0)
		if wave.has_method("setup"):
			wave.setup(dir)


func apply_direct_hit(dano: int, hit_window: float = 0.2) -> void:
	var area: Area2D = punch_hitbox if punch_hitbox else damage_area
	if not area:
		return
	var timer: float = 0.0
	var acertou: bool = false

	while timer < hit_window and not acertou and current_state != State.DEATH:
		for b: Node2D in area.get_overlapping_bodies():
			if b.is_in_group("player") and b != self and b.has_method("take_damage"):
				b.take_damage(dano, global_position)
				acertou = true
				break
		timer += get_physics_process_delta_time()
		await get_tree().physics_frame


func step_forward(speed_impulse: float, duration: float = 0.35) -> void:
	var forward_dir: int = -1 if (sprite and sprite.flip_h) else 1
	velocity.x = float(forward_dir) * speed_impulse

	var timer: float = 0.0
	while timer < duration and current_state != State.DEATH:
		var dt: float = get_physics_process_delta_time()
		velocity.x = move_toward(velocity.x, 0.0, (speed_impulse / duration) * dt)
		timer += dt
		await get_tree().physics_frame

	velocity.x = 0.0


func walk_then_idle(duration: float = walk_duration) -> void:
	if current_state == State.DEATH:
		return

	walk_direction = [-1, 1].pick_random()

	await get_tree().create_timer(0.6).timeout
	if anim and anim.has_animation("idle"):
		anim.play("idle")
	flip_sprite(float(walk_direction))
	if current_state == State.DEATH:
		return

	current_state = State.RUN
	await get_tree().create_timer(duration).timeout
	if current_state == State.DEATH:
		return

	velocity.x = 0.0
	current_state = State.IDLE
	decision_timer.start(attack_cooldown)


func flip_sprite(dir: float) -> void:
	if dir == 0.0:
		return
	if sprite:
		sprite.flip_h = (dir < 0.0)
	if punch_hitbox:
		punch_hitbox.scale.x = -1.0 if dir < 0.0 else 1.0
	if ponto_de_tiro:
		ponto_de_tiro.position.x = -absf(ponto_de_tiro.position.x) if dir < 0.0 else absf(ponto_de_tiro.position.x)


func _is_player_catchable(p: Node2D) -> bool:
	if "is_dashing" in p and p.is_dashing:
		return false
	if "is_dash_invincible" in p and p.is_dash_invincible:
		return false
	if "is_dead" in p and p.is_dead:
		return false
	return true
