extends BossBase

enum State {
	IDLE,
	RUN,
	OVERLOAD_PREP,
	OVERLOAD,
	PINBALL_PREP,
	PINBALL,
	FALSE_TELEGRAPH_PREP,
	FALSE_TELEGRAPH_FAIL,
	FALSE_TELEGRAPH_BARRAGE,
	INHIBITORY_BREAK_SLOW_PREP, # Carregando o ataque lento
	INHIBITORY_BREAK_BURST,     # Cancelamento impulsivo e investida rápida corporal
	DEATH
}

@export_group("Ataque: Chuva de Distrações (Sobrecarga Estática)")
@export var projectile_scene: PackedScene
@export var total_distractions: int = 24            # Quantidade total de distrações conjuradas
@export var telegraph_duration: float = 1.1         # Tempo em que tremem/voláteis antes de agir
@export var active_duration: float = 0.7            # Duração da explosão/dano
@export var dangerous_projectile_chance: float = 0.25 # ~25% de chance de ser vermelho perigoso
@export var field_width: float = 850.0              # Largura da área de conjuração à frente do boss
@export var field_height: float = 380.0             # Altura da área de dispersão

@export_group("Ataque: Inquietação Motora (Pinball)")
@export var pinball_speed: float = 850.0            # Altíssima velocidade para quicar
@export var pinball_bounces_target: int = 8         # Quantidade de quiques antes de parar
@export var pinball_damage: int = 25                # Dano ao colidir com o jogador no modo pinball
@export var arena_bounds_min: Vector2 = Vector2(70.0, 100.0)
@export var arena_bounds_max: Vector2 = Vector2(1210.0, 615.0)

@export_group("Ataque: Falha de Ignição & Surto em Leque")
@export var false_telegraph_duration: float = 2.0       # Tempo de carregamento "ameaçador"
@export var fail_chance: float = 0.70                   # 70% de chance de falhar no último frame (maior chance de falha)
@export var stun_confused_duration: float = 0.9         # Tempo que fica sem reação após o curto-circuito
@export var barrage_waves: int = 11                     # Quantas levas consecutivas no leque quando NÃO falhar
@export var projectiles_per_wave: int = 7               # Projéteis por onda no leque
@export var barrage_spread_angle: float = 65.0          # Ângulo de abertura do leque

@export_group("Ataque: Quebra de Freio Inibitório")
@export var min_telegraph_time: float = 0.35            # Tempo mínimo justo para reação humana
@export var max_telegraph_time: float = 1.10            # Tempo máximo (quando a hesitação é maior)
@export var burst_dash_speed: float = 950.0             # Velocidade fulminante da investida impulsiva
@export var burst_dash_duration: float = 0.32           # Duração do avanço corporal
@export var burst_dash_damage: int = 28                 # Dano de atropelamento

@export_group("Cores dos Estímulos")
@export var dangerous_color: Color = Color(1.0, 0.15, 0.15, 1.0) # Vermelho vivo (dano real)
@export var fake_colors: Array[Color] = [
	Color(0.2, 0.8, 1.0, 0.85),  # Ciano elétrico
	Color(1.0, 0.9, 0.2, 0.85),  # Amarelo estimulante
	Color(0.3, 1.0, 0.4, 0.85),  # Verde limão
	Color(0.85, 0.3, 1.0, 0.85), # Roxo/Magenta
	Color(1.0, 0.4, 0.8, 0.85)   # Rosa vibrante
]

@onready var ponto_de_tiro: Marker2D = get_node_or_null("PontoDeTiro")

var current_state: State = State.IDLE
var contact_damage_cooldown: float = 0.0

# Variáveis do estado Pinball
var pinball_velocity: Vector2 = Vector2.ZERO
var pinball_bounces_done: int = 0
var original_sprite_scale: Vector2 = Vector2.ONE

# Variáveis de investida rápida
var burst_direction: float = 1.0

# Controle da primeira execução do leque
var has_fired_first_barrage: bool = false

func _setup_dialogues() -> void:
	dialogos_inicio = [
		{"icone": player_icon, "texto": "Tantas ideias e impulsos ao mesmo tempo... Preciso manter a calma e focar no que importa!"},
		{"icone": boss_icon, "texto": "Olhe para lá! E para cá! Tantos estímulos... você nunca vai conseguir escolher um só!"},
		{"icone": player_icon, "texto": "Não vou me perder no caos. Eu decido para onde vai a minha atenção!"}
	]
	
	dialogos_vitoria = [
		{"icone": player_icon, "texto": "Consegui filtrar o ruído e focar no essencial."},
		{"icone": boss_icon, "texto": "A mente ainda corre a mil por hora..."},
		{"icone": player_icon, "texto": "E tá tudo bem ser acelerado, o segredo é direcionar essa energia sem me afogar nas distrações."}
	]

func _custom_ready() -> void:
	if sprite:
		original_sprite_scale = sprite.scale
		
	if not player:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
	
	if decision_timer:
		decision_timer.timeout.connect(_on_decision_timer_timeout)

func _can_receive_knockback() -> bool:
	return current_state not in [
		State.PINBALL, 
		State.PINBALL_PREP, 
		State.OVERLOAD, 
		State.FALSE_TELEGRAPH_PREP, 
		State.FALSE_TELEGRAPH_BARRAGE,
		State.INHIBITORY_BREAK_SLOW_PREP,
		State.INHIBITORY_BREAK_BURST
	]

func _physics_process(delta: float) -> void:
	if is_dead or current_state == State.DEATH:
		if not is_on_floor():
			velocity.y += gravity * delta
		else:
			velocity.y = 0.0
		velocity.x = 0.0
		move_and_slide()
		return

	if current_state == State.PINBALL:
		_process_pinball_movement(delta)
		return

	if not is_on_floor():
		velocity.y += gravity * delta

	if is_in_knockback:
		move_and_slide()
		return

	if contact_damage_cooldown > 0.0:
		contact_damage_cooldown -= delta
	else:
		if current_state == State.INHIBITORY_BREAK_BURST:
			_process_contact_damage(burst_dash_damage)
		else:
			_process_contact_damage()

	match current_state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, speed)
		State.RUN:
			if player:
				var dist_x: float = abs(player.global_position.x - global_position.x)
				if dist_x > 250.0:
					var dir: float = sign(player.global_position.x - global_position.x)
					velocity.x = dir * speed
					flip_sprite(dir)
				else:
					velocity.x = 0.0
					decision_timer.stop()
					current_state = [State.OVERLOAD_PREP, State.PINBALL_PREP, State.FALSE_TELEGRAPH_PREP, State.INHIBITORY_BREAK_SLOW_PREP].pick_random()
					execute_attack_sequence()
		State.INHIBITORY_BREAK_BURST:
			velocity.x = burst_direction * burst_dash_speed

	if current_state in [State.IDLE, State.RUN, State.INHIBITORY_BREAK_BURST]:
		move_and_slide()

func _process_contact_damage(dmg: int = -1) -> void:
	if not damage_area:
		return
	var applied_damage = attack_value if dmg < 0 else dmg
	var bodies: Array[Node2D] = damage_area.get_overlapping_bodies()
	for body in bodies:
		if body != self and body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(applied_damage, global_position)
			contact_damage_cooldown = 0.5
			break

func _on_decision_timer_timeout() -> void:
	if current_state != State.IDLE and current_state != State.RUN:
		return
	decision_timer.stop()
	
	var choices: Array[State] = [
		State.RUN,
		State.OVERLOAD_PREP, 
		State.PINBALL_PREP, 
		State.FALSE_TELEGRAPH_PREP,
		State.INHIBITORY_BREAK_SLOW_PREP
	]
	current_state = choices.pick_random()
	execute_attack_sequence()

func execute_attack_sequence() -> void:
	match current_state:
		State.RUN:
			decision_timer.start(attack_cooldown)
			
		State.OVERLOAD_PREP:
			velocity.x = 0.0
			if player:
				flip_sprite(sign(player.global_position.x - global_position.x))
			
			flash()
			await get_tree().create_timer(0.4).timeout
			if is_dead: return
			
			current_state = State.OVERLOAD
			await attack_sobrecarga_estimulos()
			if is_dead: return
			
			current_state = State.IDLE
			decision_timer.start(attack_cooldown)

		State.PINBALL_PREP:
			velocity = Vector2.ZERO
			current_state = State.PINBALL_PREP
			await start_pinball_sequence()

		State.FALSE_TELEGRAPH_PREP:
			velocity = Vector2.ZERO
			await start_false_telegraph_sequence()

		State.INHIBITORY_BREAK_SLOW_PREP:
			velocity = Vector2.ZERO
			await start_inhibitory_break_sequence()

# --- GOLPE 1: SOBRECARGA DE ESTÍMULOS (CONJURAÇÃO TELEGRAPH ESTÁTICA/VOLÁTIL) ---
func attack_sobrecarga_estimulos() -> void:
	if not projectile_scene:
		return

	var facing_dir: float = -1.0 if sprite.flip_h else 1.0
	var center_x: float = global_position.x + (facing_dir * (field_width * 0.45))
	
	if player:
		center_x = lerpf(center_x, player.global_position.x, 0.6)

	for i in range(total_distractions):
		if is_dead: return

		var offset_x: float = randf_range(-field_width * 0.5, field_width * 0.5)
		var target_x: float = clampf(center_x + offset_x, 80.0, 1220.0)
		var target_y: float = randf_range(320.0, 600.0)
		var spawn_pos: Vector2 = Vector2(target_x, target_y)

		var proj = projectile_scene.instantiate()
		get_parent().add_child(proj)

		var is_danger: bool = randf() < dangerous_projectile_chance
		var proj_color: Color = dangerous_color if is_danger else fake_colors.pick_random()
		
		var telegraph_time: float = telegraph_duration + randf_range(-0.15, 0.15)
		if proj.has_method("setup"):
			proj.setup(spawn_pos, is_danger, proj_color, telegraph_time, active_duration)

		await get_tree().create_timer(0.03, false).timeout

	await get_tree().create_timer(telegraph_duration + active_duration + 0.2, false).timeout

# --- GOLPE 2: INQUIETAÇÃO MOTORA (O EFEITO PINBALL) ---
func start_pinball_sequence() -> void:
	if sprite:
		var shrink_tween = create_tween()
		shrink_tween.tween_property(sprite, "scale", original_sprite_scale * Vector2(0.65, 0.65), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	var prep_time: float = 0.55
	var timer: float = 0.0
	var initial_pos = global_position
	while timer < prep_time:
		var dt = get_process_delta_time()
		timer += dt
		if is_dead: return
		global_position = initial_pos + Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))
		await get_tree().process_frame
	
	global_position = initial_pos
	if is_dead: return

	pinball_bounces_done = 0
	var launch_dir: Vector2 = Vector2(randf_range(-1.0, 1.0), randf_range(0.4, 0.9)).normalized()
	if player:
		launch_dir = (player.global_position - global_position).normalized()
		if abs(launch_dir.y) < 0.3:
			launch_dir.y = 0.6 * sign(launch_dir.y if launch_dir.y != 0 else 1.0)
		launch_dir = launch_dir.normalized()

	pinball_velocity = launch_dir * pinball_speed
	current_state = State.PINBALL

func _process_pinball_movement(delta: float) -> void:
	velocity = pinball_velocity
	
	if sprite:
		sprite.rotation += 22.0 * delta * sign(pinball_velocity.x if pinball_velocity.x != 0 else 1.0)

	_process_contact_damage(pinball_damage)

	var collision = move_and_collide(velocity * delta)
	var bounced: bool = false

	if collision:
		pinball_velocity = pinball_velocity.bounce(collision.get_normal())
		var angle_jiggle = randf_range(-0.12, 0.12)
		pinball_velocity = pinball_velocity.rotated(angle_jiggle).normalized() * pinball_speed
		bounced = true
	else:
		if global_position.x <= arena_bounds_min.x:
			global_position.x = arena_bounds_min.x + 2.0
			pinball_velocity.x = abs(pinball_velocity.x)
			bounced = true
		elif global_position.x >= arena_bounds_max.x:
			global_position.x = arena_bounds_max.x - 2.0
			pinball_velocity.x = -abs(pinball_velocity.x)
			bounced = true

		if global_position.y <= arena_bounds_min.y:
			global_position.y = arena_bounds_min.y + 2.0
			pinball_velocity.y = abs(pinball_velocity.y)
			bounced = true
		elif global_position.y >= arena_bounds_max.y:
			global_position.y = arena_bounds_max.y - 2.0
			pinball_velocity.y = -abs(pinball_velocity.y)
			bounced = true

	if bounced:
		pinball_bounces_done += 1
		flash()
		
		if sprite:
			var bounce_tween = create_tween()
			bounce_tween.tween_property(sprite, "scale", original_sprite_scale * Vector2(0.85, 0.5), 0.05)
			bounce_tween.tween_property(sprite, "scale", original_sprite_scale * Vector2(0.65, 0.65), 0.08)

		if pinball_bounces_done >= pinball_bounces_target:
			_end_pinball()

func _end_pinball() -> void:
	current_state = State.IDLE
	velocity = Vector2.ZERO
	pinball_velocity = Vector2.ZERO
	
	if sprite:
		var restore_tween = create_tween()
		restore_tween.set_parallel(true)
		restore_tween.tween_property(sprite, "scale", original_sprite_scale, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		restore_tween.tween_property(sprite, "rotation", 0.0, 0.2)
	
	decision_timer.start(attack_cooldown)

# --- GOLPE 3: A FALHA DE IGNIÇÃO COM CHANCE DE DISPARO REAL EM LEQUE ---
func start_false_telegraph_sequence() -> void:
	velocity = Vector2.ZERO
	if player:
		flip_sprite(sign(player.global_position.x - global_position.x))

	var initial_pos = global_position
	var initial_sprite_pos = sprite.position if sprite else Vector2.ZERO

	if anim.has_animation("prep_explosion"):
		anim.play("prep_explosion")

	if sprite:
		var charge_tween = create_tween()
		charge_tween.set_parallel(true)
		charge_tween.tween_property(sprite, "scale", original_sprite_scale * Vector2(1.35, 1.45), false_telegraph_duration).set_trans(Tween.TRANS_SINE)
		charge_tween.tween_property(sprite, "position:y", initial_sprite_pos.y - 25.0, false_telegraph_duration)

	var elapsed: float = 0.0
	var flash_timer: float = 0.0

	while elapsed < false_telegraph_duration:
		var dt = get_process_delta_time()
		elapsed += dt
		flash_timer += dt
		if is_dead: return

		var progress = clampf(elapsed / false_telegraph_duration, 0.0, 1.0)
		var shake_intensity = lerpf(2.0, 9.0, progress)

		global_position = initial_pos + Vector2(randf_range(-shake_intensity, shake_intensity), randf_range(-shake_intensity, shake_intensity))
		_apply_arena_screen_shake(shake_intensity * 0.75)

		var flash_rate = lerpf(0.2, 0.05, progress)
		if flash_timer >= flash_rate:
			flash_timer = 0.0
			_flash_custom(Color(1.0, 0.9, 0.2, 1.0) if randf() > 0.5 else Color.WHITE, 0.6)

		await get_tree().process_frame

	global_position = initial_pos
	_apply_arena_screen_shake(0.0)

	if is_dead: return

	# Se for a primeira vez na luta, o ataque tem 100% de chance de disparar (sem falha)
	var will_fail: bool = false
	if not has_fired_first_barrage:
		will_fail = false
		has_fired_first_barrage = true
	else:
		will_fail = randf() < fail_chance

	if will_fail:
		current_state = State.FALSE_TELEGRAPH_FAIL
		_flash_custom(Color(0.4, 0.4, 0.4, 1.0), 1.0)

		if sprite:
			var pop_down = create_tween()
			pop_down.set_parallel(true)
			pop_down.tween_property(sprite, "scale", original_sprite_scale * Vector2(1.1, 0.7), 0.08)
			pop_down.tween_property(sprite, "position", initial_sprite_pos, 0.08)
			await pop_down.finished
			
			var restore = create_tween()
			restore.tween_property(sprite, "scale", original_sprite_scale, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

		await get_tree().create_timer(stun_confused_duration, false).timeout
		if is_dead: return

		current_state = State.IDLE
		if anim.has_animation("idle"):
			anim.play("idle")
		decision_timer.start(attack_cooldown)

	else:
		current_state = State.FALSE_TELEGRAPH_BARRAGE
		_flash_custom(Color(1.0, 0.2, 0.2, 1.0), 1.0)
		_apply_arena_screen_shake(6.0)

		if sprite:
			var shoot_tween = create_tween()
			shoot_tween.set_parallel(true)
			shoot_tween.tween_property(sprite, "scale", original_sprite_scale, 0.15)
			shoot_tween.tween_property(sprite, "position", initial_sprite_pos, 0.15)

		await _fire_barrage_fan()
		_apply_arena_screen_shake(0.0)
		if is_dead: return

		current_state = State.IDLE
		if anim.has_animation("idle"):
			anim.play("idle")
		decision_timer.start(attack_cooldown)

func _fire_barrage_fan() -> void:
	if not projectile_scene: return
	var spawn_pos: Vector2 = ponto_de_tiro.global_position if ponto_de_tiro else global_position
	
	var base_direction: Vector2 = Vector2.LEFT if sprite.flip_h else Vector2.RIGHT
	if player:
		base_direction = spawn_pos.direction_to(player.global_position)

	var base_angle: float = base_direction.angle()
	var half_spread_rad: float = deg_to_rad(barrage_spread_angle) / 2.0

	for wave in range(barrage_waves):
		if is_dead: return
		var wave_angle_offset: float = deg_to_rad(randf_range(-8.0, 8.0))
		
		for i in range(projectiles_per_wave):
			var t: float = 0.5
			if projectiles_per_wave > 1:
				t = float(i) / float(projectiles_per_wave - 1)
			
			var angle: float = (base_angle - half_spread_rad) + (t * deg_to_rad(barrage_spread_angle)) + wave_angle_offset
			var dir: Vector2 = Vector2(cos(angle), sin(angle))
			
			var proj = projectile_scene.instantiate()
			get_parent().add_child(proj)
			
			var is_danger: bool = randf() < dangerous_projectile_chance
			var proj_color: Color = dangerous_color if is_danger else fake_colors.pick_random()
			var proj_speed: float = randf_range(380.0, 520.0)
			
			if proj.has_method("setup_moving"):
				proj.setup_moving(spawn_pos, dir, proj_speed, is_danger, proj_color)

		await get_tree().create_timer(0.12, false).timeout

# --- GOLPE 4: QUEBRA DE FREIO INIBITÓRIO (CANCELAMENTO IMPULSIVO + BOTE RÁPIDO) ---
func start_inhibitory_break_sequence() -> void:
	velocity = Vector2.ZERO
	current_state = State.INHIBITORY_BREAK_SLOW_PREP

	if player:
		burst_direction = signf(player.global_position.x - global_position.x)
		if burst_direction == 0.0: burst_direction = 1.0
		flip_sprite(burst_direction)
	else:
		burst_direction = -1.0 if sprite.flip_h else 1.0

	var initial_sprite_pos = sprite.position if sprite else Vector2.ZERO

	# 1. Duração aleatória do telegraph nesta ativação
	var current_telegraph_time: float = randf_range(min_telegraph_time, max_telegraph_time)

	# Simulação do golpe: recuo pesado para trás (winding up) proporcional ao tempo sorteado
	var windup_tween = create_tween()
	windup_tween.set_parallel(true)
	if sprite:
		windup_tween.tween_property(sprite, "position:x", initial_sprite_pos.x - (burst_direction * 22.0), current_telegraph_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		windup_tween.tween_property(sprite, "scale", original_sprite_scale * Vector2(0.85, 1.2), current_telegraph_time)

	# 2. Aguarda o tempo aleatório sorteado
	await get_tree().create_timer(current_telegraph_time, false).timeout
	if is_dead: return

	# Interrompe o windup bruscamente
	if windup_tween.is_valid():
		windup_tween.kill()

	# 3. O ESTALO IMPULSIVO (Impatience Snap)
	# Pisca com cor de alerta elétrico repentino
	_flash_custom(Color(1.0, 0.3, 0.1, 1.0), 1.0)
	_apply_arena_screen_shake(3.5)

	# Projeta o sprite inclinado para frente (squash agressivo de arrancada)
	if sprite:
		var snap_tween = create_tween()
		snap_tween.tween_property(sprite, "position", initial_sprite_pos, 0.05)
		snap_tween.tween_property(sprite, "scale", original_sprite_scale * Vector2(1.35, 0.75), 0.06)

	await get_tree().create_timer(0.06, false).timeout
	_apply_arena_screen_shake(0.0)
	if is_dead: return

	# 4. DISPARADA/BOTE CORPORAL EM ALTÍSSIMA VELOCIDADE
	current_state = State.INHIBITORY_BREAK_BURST
	if anim.has_animation("dash"):
		anim.play("dash")

	# Dá a investida corporal rápida
	var burst_timer: float = 0.0
	while burst_timer < burst_dash_duration:
		var dt = get_process_delta_time()
		burst_timer += dt
		if is_dead: return
		
		# Se bater na parede da arena, interrompe o dash
		if is_on_wall():
			break
		await get_tree().process_frame

	# 5. Freio brusco / Recuperação
	velocity.x = 0.0
	current_state = State.IDLE

	if sprite:
		var restore_tween = create_tween()
		restore_tween.tween_property(sprite, "scale", original_sprite_scale, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if anim.has_animation("idle"):
		anim.play("idle")

	decision_timer.start(attack_cooldown)

func flash() -> void:
	if not sprite or not sprite.material: return
	var mat = sprite.material
	mat.set_shader_parameter("flash_color", Color.WHITE)
	var tween = create_tween()
	tween.tween_property(mat, "shader_parameter/flash_modifier", 1.0, 0.0)
	tween.tween_property(mat, "shader_parameter/flash_modifier", 0.0, 0.15)

func _flash_custom(color: Color, modifier: float = 1.0) -> void:
	if not sprite or not sprite.material: return
	var mat = sprite.material
	mat.set_shader_parameter("flash_color", color)
	mat.set_shader_parameter("flash_modifier", modifier)
	var t = create_tween()
	t.tween_property(mat, "shader_parameter/flash_modifier", 0.0, 0.08)
	t.tween_callback(func():
		if mat:
			mat.set_shader_parameter("flash_color", Color.WHITE)
	)

func _apply_arena_screen_shake(intensity: float) -> void:
	var canvas_transform = get_viewport().canvas_transform
	if intensity > 0.0:
		canvas_transform.origin = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
	else:
		canvas_transform.origin = Vector2.ZERO
	get_viewport().canvas_transform = canvas_transform

func _on_death() -> void:
	current_state = State.DEATH
	if decision_timer:
		decision_timer.stop()
	if sprite:
		sprite.rotation = 0.0
		sprite.scale = original_sprite_scale
		sprite.position = Vector2.ZERO
	_apply_arena_screen_shake(0.0)
