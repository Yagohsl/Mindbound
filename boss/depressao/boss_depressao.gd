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
@export var geiser_spacing: float = 250.0
@export var min_geiser_count: int = 1
@export var max_geiser_count: int = 4

@export_group("Chuva de Lágrimas")
@export var rain_drops_count: int = 14
@export var rain_spawn_y: float = -40.0
@export var arena_min_x: float = 80.0
@export var arena_max_x: float = 1200.0

@export_group("Pensamentos Ruins")
@export var rush_speed: float = 650.0
@export var smash_heavy_damage: int = 40

@onready var ponto_de_tiro: Marker2D = get_node_or_null("PontoDeTiro")
@onready var punch_hitbox: Area2D = get_node_or_null("PunchHitbox")

var current_state: State = State.IDLE
var damage_cooldown: float = 0.0
var walk_direction: int = 1
var direct_attack_stage: int = 1
var current_geiser_count: int = 1

var rush_direction: int = 0
var rush_duration: float = 0.45
var player_caught: bool = false

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

func _apply_dynamic_difficulty(life_percent: float) -> void:
	current_geiser_count = roundi(lerp(float(max_geiser_count), float(min_geiser_count), life_percent))
	current_geiser_count = clampi(current_geiser_count, min_geiser_count, max_geiser_count)
	
	if life_percent > 0.60:
		direct_attack_stage = 1
	elif life_percent > 0.30:
		direct_attack_stage = 2
	else:
		direct_attack_stage = 3

func _can_receive_knockback() -> bool:
	return current_state not in [State.MINIGAME, State.BAD_THOUGHTS]

func _on_death() -> void:
	current_state = State.DEATH
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

	match current_state:
		State.IDLE:
			anim.play("idle")
			velocity.x = move_toward(velocity.x, 0.0, speed)

		State.RUN:
			if is_on_wall():
				walk_direction *= -1
				flip_sprite(walk_direction)
			velocity.x = walk_direction * speed
			anim.play("idle")

		State.GEISER_PREP, State.GEISER, State.PROJECTILE, State.RAIN, State.MINIGAME, State.DIRECT_ATTACK_PREP:
			velocity.x = 0.0

		State.DIRECT_ATTACK, State.BAD_THOUGHTS:
			pass

	if current_state == State.BAD_THOUGHTS and not player_caught:
		for body in damage_area.get_overlapping_bodies():
			if body.is_in_group("player") and body != self:
				trigger_thoughts_minigame(body)
				break

	_process_contact_damage()

	if current_state in [State.IDLE, State.RUN, State.BAD_THOUGHTS, State.DIRECT_ATTACK]:
		move_and_slide()

func _process_contact_damage() -> void:
	if player_caught or current_state in [State.BAD_THOUGHTS_PREP, State.BAD_THOUGHTS, State.MINIGAME]:
		return
		
	if damage_cooldown <= 0.0:
		for body in damage_area.get_overlapping_bodies():
			if body.is_in_group("player") and body != self and body.has_method("take_damage"):
				body.take_damage(attack_value, global_position)
				damage_cooldown = 1.0
				break

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
			if player:
				flip_sprite(player.global_position.x - global_position.x)
			
			velocity.x = 0.0
			anim.play("prep_throw_projectile")
			await get_tree().create_timer(0.5).timeout
			if current_state == State.DEATH: return

			anim.play("throw_projectile")
			fire_lodo()
			await get_tree().create_timer(0.7).timeout
			if current_state == State.DEATH: return
			anim.play("idle")
			await walk_then_idle()

		State.GEISER_PREP:
			velocity.x = 0.0
			if anim.has_animation("prep_geiser"):
				anim.play("prep_geiser")
			
			if player:
				flip_sprite(player.global_position.x - global_position.x)
			
			await get_tree().create_timer(0.6).timeout
			if current_state == State.DEATH: return
			
			current_state = State.GEISER
			execute_attack_sequence()

		State.GEISER:
			velocity.x = 0.0
			if anim.has_animation("attack_geiser"):
				anim.play("attack_geiser")
			
			spawn_geiser()
			
			if anim.is_playing() and anim.current_animation == "attack_geiser":
				await anim.animation_finished
			else:
				await get_tree().create_timer(0.5).timeout
				
			if current_state == State.DEATH: return
			await walk_then_idle()

		State.RAIN:
			velocity.x = 0.0
			await start_tear_rain()
			if current_state == State.DEATH: return
			await walk_then_idle()

		State.BAD_THOUGHTS_PREP:
			velocity.x = 0.0
			anim.play("prep_rush")
			
			if player:
				rush_direction = signi(int(player.global_position.x - global_position.x))
				flip_sprite(rush_direction)
			
			await get_tree().create_timer(0.4).timeout
			if current_state == State.DEATH: return
			
			player_caught = false
			current_state = State.BAD_THOUGHTS
			execute_attack_sequence()

		State.BAD_THOUGHTS:
			anim.play("rush")
			velocity.x = rush_direction * rush_speed
			
			var elapsed: float = 0.0
			while elapsed < rush_duration:
				if player_caught or current_state == State.DEATH or is_on_wall():
					break
				elapsed += get_physics_process_delta_time()
				await get_tree().physics_frame
			
			velocity.x = 0.0
			
			if not player_caught and current_state != State.MINIGAME:
				await get_tree().create_timer(0.3).timeout
				if current_state == State.DEATH: return
				await walk_then_idle()

		State.DIRECT_ATTACK_PREP:
			velocity.x = 0.0
			if player:
				flip_sprite(player.global_position.x - global_position.x)
				
			anim.play("prep_direct")
			await get_tree().create_timer(0.8).timeout
			if current_state == State.DEATH: return
			
			current_state = State.DIRECT_ATTACK
			execute_attack_sequence()

		State.DIRECT_ATTACK:
			velocity.x = 0.0
			await run_direct_attack_combo()

func fire_lodo() -> void:
	if not projectile_scene or not player:
		return
	
	var proj: Node2D = projectile_scene.instantiate()
	var spawn_pos: Vector2 = ponto_de_tiro.global_position if ponto_de_tiro else global_position
	
	proj.global_position = spawn_pos
	get_parent().add_child(proj)
	
	var dir: Vector2 = spawn_pos.direction_to(player.global_position)
	if proj.has_method("setup"):
		proj.setup(dir)

func spawn_geiser() -> void:
	if not geiser_scene or not player:
		return
		
	var count: int = current_geiser_count
	var center_x: float = player.global_position.x
	var ground_y: float = global_position.y
	
	var total_width: float = (count - 1) * geiser_spacing
	var start_x: float = center_x - (total_width / 2.0)
	
	for i in range(count):
		var geiser: Node2D = geiser_scene.instantiate()
		var pos_x: float = start_x + (i * geiser_spacing)
		geiser.global_position = Vector2(pos_x, ground_y)
		get_parent().add_child(geiser)

func start_tear_rain() -> void:
	if not tear_scene:
		return
		
	for i in range(rain_drops_count):
		if current_state == State.DEATH:
			return
			
		var drop: Node2D = tear_scene.instantiate()
		var rand_x: float = randf_range(arena_min_x, arena_max_x)
		drop.global_position = Vector2(rand_x, rain_spawn_y)
		get_parent().add_child(drop)
		
		await get_tree().create_timer(0.2).timeout

func trigger_thoughts_minigame(target_player: CharacterBody2D) -> void:
	player_caught = true
	current_state = State.MINIGAME
	velocity.x = 0.0
	
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
		velocity.x = -rush_direction * 250.0

	damage_cooldown = 1.2
	player_caught = false
	
	if current_state == State.DEATH:
		return
		
	await walk_then_idle()

func run_direct_attack_combo() -> void:
	anim.play("attack_direct")
	step_forward(punch_forward_impulse, 0.25)
	apply_direct_hit(direct_attack_damage, 0.25)
	
	anim.play("attack_direct")
	await anim.animation_finished
	
	if current_state == State.DEATH: return

	if direct_attack_stage >= 2:
		await get_tree().create_timer(0.2).timeout
		if current_state == State.DEATH: return
		
		anim.play("attack_direct_2")
		step_forward(punch_forward_impulse, 0.25)
		apply_direct_hit(direct_attack_damage, 0.25)
		
		if anim.is_playing() and anim.current_animation == "attack_direct_2":
			await anim.animation_finished
		else:
			await get_tree().create_timer(0.35).timeout
		if current_state == State.DEATH: return

	if direct_attack_stage == 3:
		if current_state == State.DEATH: return
		if player:
			flip_sprite(player.global_position.x - global_position.x)
			
		await get_tree().create_timer(0.25).timeout
		anim.play("slam")
		
		step_forward(punch_forward_impulse * 1.3, 0.3)
		apply_direct_hit(slam_damage, 0.3)
		
		await get_tree().create_timer(0.25).timeout
		spawn_cortina_lodo()
		
		if anim.is_playing() and anim.current_animation == "slam":
			await anim.animation_finished
		else:
			await get_tree().create_timer(0.4).timeout
		if current_state == State.DEATH: return

	await walk_then_idle()

func spawn_cortina_lodo() -> void:
	if not slam_shockwave_scene:
		return
		
	for dir in [-1, 1]:
		var wave: Node2D = slam_shockwave_scene.instantiate()
		wave.global_position = Vector2(global_position.x + (dir * 40.0), global_position.y)
		if wave.has_method("setup"):
			wave.setup(dir)
		get_parent().add_child(wave)

func apply_direct_hit(dano: int, hit_window: float = 0.2) -> void:
	var area: Area2D = punch_hitbox if punch_hitbox else damage_area
	var timer: float = 0.0
	var acertou: bool = false
	
	while timer < hit_window and not acertou and current_state != State.DEATH:
		for b in area.get_overlapping_bodies():
			if b.is_in_group("player") and b != self and b.has_method("take_damage"):
				b.take_damage(dano, global_position)
				acertou = true
				break
		timer += get_physics_process_delta_time()
		await get_tree().physics_frame

func step_forward(speed_impulse: float, duration: float = 0.35) -> void:
	var forward_dir: int = -1 if sprite.flip_h else 1
	velocity.x = forward_dir * speed_impulse
	
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
	anim.play("idle")
	flip_sprite(walk_direction)
	if current_state == State.DEATH: return
	
	current_state = State.RUN
	await get_tree().create_timer(duration).timeout
	if current_state == State.DEATH: return
		
	velocity.x = 0.0
	current_state = State.IDLE
	decision_timer.start(attack_cooldown)

# Sobrescreve a função nativa da BossBase para inverter hitboxes e marcadores
func flip_sprite(dir: float) -> void:
	if dir == 0.0:
		return
	sprite.flip_h = (dir < 0.0)
	if punch_hitbox:
		punch_hitbox.scale.x = -1.0 if dir < 0.0 else 1.0
	if ponto_de_tiro:
		ponto_de_tiro.position.x = -abs(ponto_de_tiro.position.x) if dir < 0 else abs(ponto_de_tiro.position.x)
