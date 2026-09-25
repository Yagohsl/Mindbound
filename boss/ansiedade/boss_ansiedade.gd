extends BossBase

enum State { IDLE, RUN, THOUGHTS, TELEPORT, EXPLOSION_PREP, EXPLOSION, DASH_PREP, DASH, DEATH }

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

@onready var ponto_de_tiro: Marker2D = $PontoDeTiro

var current_state: State = State.IDLE
var current_dash_prep: float = 0.7
var current_teleport_wait: float = 1.0
var dash_direction: int = 0
var dash_distance_left: float = 0.0
var contact_damage_cooldown: float = 0.0

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
	attack_cooldown = lerp(min_attack_cooldown, max_attack_cooldown, life_percent)
	current_dash_prep = lerp(min_dash_prep, max_dash_prep, life_percent)
	current_teleport_wait = lerp(min_teleport_wait, max_teleport_wait, life_percent)

func _on_death() -> void:
	current_state = State.DEATH
	decision_timer.stop()

func _physics_process(delta: float) -> void:
	if current_state == State.DEATH:
		if not is_on_floor(): velocity.y += gravity * delta
		else: velocity.y = 0.0
		if is_in_knockback: move_and_slide(); return
		velocity.x = 0.0
		move_and_slide()
		return

	if not is_on_floor() and current_state != State.TELEPORT:
		velocity.y += gravity * delta

	if is_in_knockback:
		move_and_slide()
		return

	if contact_damage_cooldown > 0.0:
		contact_damage_cooldown -= delta
	else:
		_process_contact_damage()

	match current_state:
		State.IDLE:
			anim.play("idle")
			velocity.x = move_toward(velocity.x, 0.0, speed)
		
		State.RUN:
			if player:
				var dist_x: float = abs(player.global_position.x - global_position.x)
				if dist_x > stop_distance:
					var dir: float = sign(player.global_position.x - global_position.x)
					velocity.x = dir * speed
					flip_sprite(dir)
					anim.play("run")
				else:
					velocity.x = 0.0
					decision_timer.stop()
					current_state = State.DASH_PREP
					execute_attack_sequence()
		
		State.DASH:
			anim.play("dash")
			var progress_ratio: float = clamp(dash_distance_left / dash_max_distance, 0.0, 1.0)
			var min_dash_speed: float = speed * 0.8
			var current_speed: float = dash_speed

			if progress_ratio < 0.25:
				var ease_t: float = progress_ratio / 0.25
				current_speed = lerp(min_dash_speed, dash_speed, ease_t)

			var step: float = current_speed * delta
			velocity.x = dash_direction * current_speed
			dash_distance_left -= step

			if is_on_wall() or global_position.x <= 60 or global_position.x >= 1220:
				dash_distance_left = 0.0

			if dash_distance_left <= 0.0:
				velocity.x = 0.0
				current_state = State.IDLE
				decision_timer.start(attack_cooldown)

	if current_state in [State.IDLE, State.RUN, State.DASH]:
		move_and_slide()

func _process_contact_damage() -> void:
	var bodies: Array[Node2D] = damage_area.get_overlapping_bodies()
	for body in bodies:
		if body != self and body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(attack_value, global_position)
			contact_damage_cooldown = 1.0
			break

func _on_decision_timer_timeout() -> void:
	if current_state != State.IDLE and current_state != State.RUN: return
	decision_timer.stop()
	
	var choices: Array[State] = [State.RUN, State.DASH_PREP, State.THOUGHTS, State.EXPLOSION_PREP, State.TELEPORT]
	current_state = choices.pick_random()
	execute_attack_sequence()

func execute_attack_sequence() -> void:
	match current_state:
		State.THOUGHTS:
			velocity.x = 0.0
			if player: flip_sprite(sign(player.global_position.x - global_position.x))
			anim.play("prep_projectile")
			await get_tree().create_timer(0.5).timeout
			if current_state == State.DEATH: return
			anim.play("projectile")
			fire_preoccupation()
			await anim.animation_finished
			if current_state == State.DEATH: return
			current_state = State.IDLE
			decision_timer.start(attack_cooldown)
			
		State.RUN:
			anim.play("run")
			decision_timer.start(attack_cooldown)
			
		State.EXPLOSION_PREP:
			velocity.x = 0.0
			anim.play("prep_explosion")
			await get_tree().create_timer(0.5).timeout
			if current_state == State.DEATH: return
			current_state = State.EXPLOSION
			anim.play("explosion")
			fire_explosion()
			await get_tree().create_timer(0.4).timeout
			if current_state == State.DEATH: return
			current_state = State.IDLE
			decision_timer.start(attack_cooldown)
			
		State.TELEPORT:
			velocity = Vector2.ZERO
			anim.play("explosion")
			await teleport_routine()
			if current_state == State.DEATH: return
			current_state = State.IDLE
			decision_timer.start(attack_cooldown)
			
		State.DASH_PREP:
			velocity.x = 0.0
			if player:
				dash_direction = int(sign(player.global_position.x - global_position.x))
				if dash_direction == 0: dash_direction = 1
				flip_sprite(dash_direction)
			anim.play("prep_dash")
			await get_tree().create_timer(current_dash_prep).timeout
			if current_state == State.DEATH: return
			dash_distance_left = dash_max_distance
			current_state = State.DASH

func fire_preoccupation() -> void:
	if not projectile_scene or not player: return
	var spawn_pos: Vector2 = ponto_de_tiro.global_position if ponto_de_tiro else global_position
	var proj = projectile_scene.instantiate()
	proj.global_position = spawn_pos
	get_parent().add_child(proj)
	var angle: float = spawn_pos.direction_to(player.global_position).angle() + randf_range(-0.2, 0.2)
	proj.setup(angle, 500.0)

func fire_explosion() -> void:
	if not projectile_scene: return
	var spawn_pos: Vector2 = ponto_de_tiro.global_position if ponto_de_tiro else global_position
	var num_projectiles: int = 12
	for i in range(num_projectiles):
		var proj = projectile_scene.instantiate()
		proj.global_position = spawn_pos
		get_parent().add_child(proj)
		var angle: float = (2.0 * PI / float(num_projectiles)) * float(i)
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
			var far_from_boss: bool = abs(target_pos.x - global_position.x) >= min_teleport_distance
			var far_from_player: bool = true
			if player:
				far_from_player = target_pos.distance_to(player.global_position) >= min_player_teleport_distance
			if far_from_boss and far_from_player:
				valid_position = true

		if teleport_warning_scene:
			var warning = teleport_warning_scene.instantiate()
			warning.global_position = target_pos
			get_parent().add_child(warning)

		await get_tree().create_timer(current_teleport_wait, false, false, true).timeout
		if current_state == State.DEATH: return
		global_position = target_pos
		teleports_done += 1
		
		if teleports_done < 3:
			await get_tree().create_timer(0.3, false, false, true).timeout
			if current_state == State.DEATH: return
