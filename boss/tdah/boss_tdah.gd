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
	INHIBITORY_BREAK_SLOW_PREP,
	INHIBITORY_BREAK_BURST,
	WHIRLWIND_PREP,
	WHIRLWIND_SWEEP,
	WHIRLWIND_EXPLOSION,
	DEATH
}

const NEUTRAL_STATES: Array[State] = [State.IDLE, State.RUN]
const SLIDING_STATES: Array[State] = [
	State.IDLE,
	State.RUN,
	State.INHIBITORY_BREAK_BURST,
	State.WHIRLWIND_SWEEP
]
const KNOCKBACK_IMMUNE_STATES: Array[State] = [
	State.PINBALL,
	State.PINBALL_PREP,
	State.OVERLOAD,
	State.FALSE_TELEGRAPH_PREP,
	State.FALSE_TELEGRAPH_BARRAGE,
	State.INHIBITORY_BREAK_SLOW_PREP,
	State.INHIBITORY_BREAK_BURST,
	State.WHIRLWIND_PREP,
	State.WHIRLWIND_SWEEP,
	State.WHIRLWIND_EXPLOSION
]

@export_group("Ataque: Chuva de Distrações (Sobrecarga Estática)")
@export var projectile_scene: PackedScene
@export var total_distractions: int = 24
@export var telegraph_duration: float = 1.1
@export var active_duration: float = 0.7
@export var dangerous_projectile_chance: float = 0.20
@export var field_width: float = 850.0
@export var field_height: float = 380.0

@export_group("Ataque: Inquietação Motora (Pinball)")
@export var pinball_speed: float = 850.0
@export var pinball_bounces_target: int = 8
@export var pinball_damage: int = 25
@export var arena_bounds_min: Vector2 = Vector2(70.0, 100.0)
@export var arena_bounds_max: Vector2 = Vector2(1210.0, 615.0)

@export_group("Ataque: Falha de Ignição & Surto em Leque")
@export var false_telegraph_duration: float = 2.0
@export var fail_chance: float = 0.70
@export var stun_confused_duration: float = 0.9
@export var barrage_waves: int = 11
@export var projectiles_per_wave: int = 7
@export var barrage_spread_angle: float = 65.0

@export_group("Ataque: Quebra de Freio Inibitório")
@export var min_telegraph_time: float = 0.35
@export var max_telegraph_time: float = 1.10
@export var burst_dash_speed: float = 950.0
@export var burst_dash_duration: float = 0.32
@export var burst_dash_damage: int = 8

@export_group("Ataque: Pêndulo Impulsivo")
@export var whirlwind_start_speed: float = 900.0
@export var whirlwind_amplitude_start: float = 550.0
@export var whirlwind_projectiles: int = 30

@export_group("Levitação")
@export var hover_height: float = 40.0
@export var hover_bob_amplitude: float = 9.0
@export var hover_bob_speed: float = 1.8

@export_group("Cores dos Estímulos")
@export var dangerous_color: Color = Color(1.0, 0.15, 0.15, 1.0)
@export var fake_colors: Array[Color] = [
	Color(0.2, 0.8, 1.0, 0.85),
	Color(1.0, 0.9, 0.2, 0.85),
	Color(0.3, 1.0, 0.4, 0.85),
	Color(0.801, 0.365, 0.99, 0.85),
	Color(0.176, 0.764, 0.64, 0.85)
]

@onready var ponto_de_tiro: Marker2D = get_node_or_null("PontoDeTiro")
@onready var body_collision: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var damage_collision: CollisionShape2D = get_node_or_null("DamageArea/CollisionShape2D")

var current_state: State = State.IDLE
var contact_damage_cooldown: float = 0.0
var last_attack: State = State.IDLE

var pinball_velocity: Vector2 = Vector2.ZERO
var pinball_bounces_done: int = 0
var original_sprite_scale: Vector2 = Vector2.ONE
var base_sprite_pos: Vector2 = Vector2.ZERO
var base_body_col_pos: Vector2 = Vector2.ZERO
var base_damage_col_pos: Vector2 = Vector2.ZERO
var hover_time: float = 0.0

var burst_direction: float = 1.0

var whirlwind_center_x: float = 0.0
var whirlwind_target_x: float = 0.0
var whirlwind_amplitude: float = 0.0
var whirlwind_current_speed: float = 0.0

var has_fired_first_barrage: bool = false
var _flash_tween: Tween


# ==============================================================================
# INICIALIZAÇÃO E HOOKS DA BOSSBASE
# ==============================================================================

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
		base_sprite_pos = sprite.position

	if body_collision:
		base_body_col_pos = body_collision.position
	if damage_collision:
		base_damage_col_pos = damage_collision.position

	if not player:
		var players: Array[Node] = get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			player = players[0]

	if decision_timer and not decision_timer.timeout.is_connected(_on_decision_timer_timeout):
		decision_timer.timeout.connect(_on_decision_timer_timeout)


func _can_receive_knockback() -> bool:
	return current_state not in KNOCKBACK_IMMUNE_STATES


func _on_death() -> void:
	current_state = State.DEATH
	_play_animation_safe("death")
	if decision_timer:
		decision_timer.stop()
	_reset_sprite_transform()
	_apply_arena_screen_shake(0.0)


# ==============================================================================
# LOOP DE FÍSICA E MOVIMENTAÇÃO
# ==============================================================================

func _physics_process(delta: float) -> void:
	if is_dead or current_state == State.DEATH:
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

	_update_contact_damage(delta)
	_process_state_movement(delta)
	_face_player_in_neutral_states()
	_process_hover_bobbing(delta)

	if current_state in SLIDING_STATES:
		move_and_slide()


func _update_contact_damage(delta: float) -> void:
	if contact_damage_cooldown > 0.0:
		contact_damage_cooldown -= delta
		return

	var dmg: int = burst_dash_damage if current_state == State.INHIBITORY_BREAK_BURST else -1
	_process_contact_damage(dmg)


func _process_state_movement(delta: float) -> void:
	match current_state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, speed)
		State.RUN:
			_process_run_state()
		State.INHIBITORY_BREAK_BURST:
			velocity.x = burst_direction * burst_dash_speed
		State.WHIRLWIND_SWEEP:
			_process_whirlwind_sweep(delta)


func _process_run_state() -> void:
	if not player:
		return

	var dist_x: float = absf(player.global_position.x - global_position.x)
	if dist_x > 250.0:
		var dir: float = signf(player.global_position.x - global_position.x)
		velocity.x = dir * speed
		flip_sprite(dir)
		return

	velocity.x = 0.0
	decision_timer.stop()
	var melee_range_attacks: Array[State] = [
		State.OVERLOAD_PREP,
		State.PINBALL_PREP,
		State.FALSE_TELEGRAPH_PREP,
		State.INHIBITORY_BREAK_SLOW_PREP,
		State.WHIRLWIND_PREP
	]
	current_state = melee_range_attacks.pick_random()
	execute_attack_sequence()


func _process_whirlwind_sweep(delta: float) -> void:
	var dir_x: float = signf(whirlwind_target_x - global_position.x)
	if dir_x == 0.0:
		dir_x = 1.0

	var dist_from_center: float = absf(global_position.x - whirlwind_center_x)
	var edge_progress: float = clampf(dist_from_center / maxf(whirlwind_amplitude, 1.0), 0.0, 1.0)
	var curve: float = cos(edge_progress * (PI * 0.5))
	var frame_speed: float = whirlwind_current_speed * lerpf(0.15, 1.0, curve)

	velocity.x = dir_x * frame_speed
	flip_sprite(dir_x)

	var sweep_progress: float = _get_whirlwind_progress()
	if sweep_progress > 0.4:
		_apply_arena_screen_shake(lerpf(0.0, 3.5, sweep_progress * sweep_progress))
		if randf() < (sweep_progress * 0.05):
			_flash_custom(Color(1.0, 0.5, 0.0, 1.0), 0.4)

	if absf(global_position.x - whirlwind_target_x) <= (frame_speed * delta) or is_on_wall():
		if not is_on_wall():
			global_position.x = whirlwind_target_x

		whirlwind_amplitude *= 0.85
		whirlwind_current_speed += 80.0
		dir_x *= -1.0

		if whirlwind_amplitude <= 20.0:
			global_position.x = whirlwind_center_x
			velocity.x = 0.0
			current_state = State.WHIRLWIND_EXPLOSION
			execute_attack_sequence()
		else:
			whirlwind_target_x = whirlwind_center_x + (dir_x * whirlwind_amplitude)


func _face_player_in_neutral_states() -> void:
	if current_state in NEUTRAL_STATES and player:
		if absf(player.global_position.x - global_position.x) > 5.0:
			_face_player()


func _process_hover_bobbing(delta: float) -> void:
	if current_state in [State.PINBALL_PREP, State.PINBALL]:
		return

	hover_time += delta
	var offset_y: float = sin(2.0 * hover_time * hover_bob_speed) * hover_bob_amplitude
	var shake_offset: Vector2 = Vector2.ZERO

	if current_state == State.WHIRLWIND_SWEEP:
		var sweep_progress: float = _get_whirlwind_progress()
		if sweep_progress > 0.4:
			var intensity: float = lerpf(0.0, 8.0, sweep_progress * sweep_progress)
			shake_offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))

	if sprite:
		sprite.position = Vector2(base_sprite_pos.x, base_sprite_pos.y - hover_height + offset_y) + shake_offset
	if ponto_de_tiro:
		ponto_de_tiro.position = Vector2(base_sprite_pos.x, base_sprite_pos.y - hover_height + offset_y) + shake_offset
	if damage_collision:
		damage_collision.position = Vector2(base_damage_col_pos.x, base_damage_col_pos.y - hover_height + offset_y) + shake_offset
	if body_collision:
		body_collision.position = base_body_col_pos


func _process_contact_damage(dmg: int = -1) -> void:
	if not damage_area:
		return

	var applied_damage: int = attack_value if dmg < 0 else dmg
	for body in damage_area.get_overlapping_bodies():
		if body != self and body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(applied_damage, global_position)
			contact_damage_cooldown = 0.5
			break


# ==============================================================================
# MÁQUINA DE DECISÃO E SEQUÊNCIAS DE ATAQUE
# ==============================================================================

func _on_decision_timer_timeout() -> void:
	if current_state not in NEUTRAL_STATES:
		return
	decision_timer.stop()

	var choices: Array[State] = [
		State.RUN,
		State.OVERLOAD_PREP,
		State.PINBALL_PREP,
		State.FALSE_TELEGRAPH_PREP,
		State.INHIBITORY_BREAK_SLOW_PREP,
		State.WHIRLWIND_PREP
	]

	var next_attack: State = choices.pick_random()
	if next_attack == last_attack:
		next_attack = choices.pick_random()

	current_state = next_attack
	last_attack = current_state
	execute_attack_sequence()


func execute_attack_sequence() -> void:
	match current_state:
		State.RUN:
			decision_timer.start(attack_cooldown)

		State.OVERLOAD_PREP:
			velocity.x = 0.0
			_face_player()
			flash()
			await get_tree().create_timer(0.4).timeout
			if is_dead:
				return

			current_state = State.OVERLOAD
			await attack_sobrecarga_estimulos()
			if not is_dead:
				_finish_attack_to_idle()

		State.PINBALL_PREP:
			velocity = Vector2.ZERO
			await start_pinball_sequence()

		State.FALSE_TELEGRAPH_PREP:
			velocity = Vector2.ZERO
			await start_false_telegraph_sequence()

		State.INHIBITORY_BREAK_SLOW_PREP:
			velocity = Vector2.ZERO
			await start_inhibitory_break_sequence()

		State.WHIRLWIND_PREP:
			await _start_whirlwind_prep()

		State.WHIRLWIND_EXPLOSION:
			await _execute_whirlwind_explosion()


# --- GOLPE 1: SOBRECARGA DE ESTÍMULOS ---

func attack_sobrecarga_estimulos() -> void:
	if not projectile_scene:
		return

	var facing_dir: float = -1.0 if sprite.flip_h else 1.0
	var center_x: float = global_position.x + (facing_dir * (field_width * 0.45))
	if player:
		center_x = lerpf(center_x, player.global_position.x, 0.6)

	for i in range(total_distractions):
		if is_dead:
			return

		var offset_x: float = randf_range(-field_width * 0.5, field_width * 0.5)
		var target_x: float = clampf(center_x + offset_x, arena_bounds_min.x + 10.0, arena_bounds_max.x - 10.0)
		var spawn_pos: Vector2 = Vector2(target_x, randf_range(320.0, 600.0))

		var proj: Node = projectile_scene.instantiate()
		get_parent().add_child(proj)

		var is_danger: bool = randf() < dangerous_projectile_chance
		var proj_color: Color = dangerous_color if is_danger else fake_colors.pick_random()
		var telegraph_time: float = telegraph_duration + randf_range(-0.15, 0.15)

		if proj.has_method("setup"):
			proj.setup(spawn_pos, is_danger, proj_color, telegraph_time, active_duration)

		await get_tree().create_timer(0.03, false).timeout

	await get_tree().create_timer(telegraph_duration + active_duration + 0.2, false).timeout


# --- GOLPE 2: INQUIETAÇÃO MOTORA (PINBALL) ---

func start_pinball_sequence() -> void:
	if sprite:
		var shrink_tween: Tween = create_tween().set_parallel(true)
		shrink_tween.tween_property(sprite, "scale", original_sprite_scale * Vector2(0.65, 0.65), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		shrink_tween.tween_property(sprite, "position", base_sprite_pos, 0.35)

	await _shake_entity_for_duration(0.55, 4.0)
	if is_dead:
		return

	pinball_bounces_done = 0
	var launch_dir: Vector2 = _calculate_pinball_launch_direction()

	pinball_velocity = launch_dir * pinball_speed
	velocity = pinball_velocity
	current_state = State.PINBALL

	if sprite:
		sprite.position = base_sprite_pos
	if body_collision:
		body_collision.position = base_body_col_pos
	if damage_collision:
		damage_collision.position = base_damage_col_pos


func _calculate_pinball_launch_direction() -> Vector2:
	if not player:
		return Vector2(randf_range(-1.0, 1.0), randf_range(0.4, 0.9)).normalized()

	var launch_dir: Vector2 = (player.global_position - global_position).normalized()
	if absf(launch_dir.y) < 0.3:
		launch_dir.y = 0.6 * (signf(launch_dir.y) if launch_dir.y != 0.0 else 1.0)
	return launch_dir.normalized()


func _process_pinball_movement(delta: float) -> void:
	velocity = pinball_velocity

	if sprite:
		var spin_dir: float = signf(pinball_velocity.x) if pinball_velocity.x != 0.0 else 1.0
		sprite.rotation += 22.0 * delta * spin_dir

	_process_contact_damage(pinball_damage)
	var collision: KinematicCollision2D = move_and_collide(velocity * delta)
	var bounced: bool = false

	if collision:
		pinball_velocity = pinball_velocity.bounce(collision.get_normal())
		pinball_velocity = pinball_velocity.rotated(randf_range(-0.12, 0.12)).normalized() * pinball_speed
		bounced = true
	else:
		bounced = _bounce_off_arena_bounds()

	velocity = pinball_velocity

	if bounced:
		pinball_bounces_done += 1
		flash()

		if sprite:
			var bounce_tween: Tween = create_tween()
			bounce_tween.tween_property(sprite, "scale", original_sprite_scale * Vector2(0.85, 0.5), 0.05)
			bounce_tween.tween_property(sprite, "scale", original_sprite_scale * Vector2(0.65, 0.65), 0.08)

		if pinball_bounces_done >= pinball_bounces_target:
			_end_pinball()


func _bounce_off_arena_bounds() -> bool:
	var bounced: bool = false

	if global_position.x <= arena_bounds_min.x:
		global_position.x = arena_bounds_min.x + 2.0
		pinball_velocity.x = absf(pinball_velocity.x)
		bounced = true
	elif global_position.x >= arena_bounds_max.x:
		global_position.x = arena_bounds_max.x - 2.0
		pinball_velocity.x = -absf(pinball_velocity.x)
		bounced = true

	if global_position.y <= arena_bounds_min.y:
		global_position.y = arena_bounds_min.y + 2.0
		pinball_velocity.y = absf(pinball_velocity.y)
		bounced = true
	elif global_position.y >= arena_bounds_max.y:
		global_position.y = arena_bounds_max.y - 2.0
		pinball_velocity.y = -absf(pinball_velocity.y)
		bounced = true

	return bounced


func _end_pinball() -> void:
	current_state = State.IDLE
	velocity = Vector2.ZERO
	pinball_velocity = Vector2.ZERO

	if sprite:
		var restore_tween: Tween = create_tween().set_parallel(true)
		restore_tween.tween_property(sprite, "scale", original_sprite_scale, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		restore_tween.tween_property(sprite, "rotation", 0.0, 0.2)

	hover_time = 0.0

	while not is_on_floor() and not is_dead:
		await get_tree().physics_frame

	if is_dead:
		return
	await get_tree().create_timer(0.5).timeout
	if is_dead:
		return

	decision_timer.start(attack_cooldown)


# --- GOLPE 3: FALHA DE IGNIÇÃO & SURTO EM LEQUE ---

func start_false_telegraph_sequence() -> void:
	velocity = Vector2.ZERO
	_face_player()

	var initial_pos: Vector2 = global_position
	var initial_sprite_pos: Vector2 = sprite.position if sprite else Vector2.ZERO

	_play_animation_safe("prep_explosion")

	var charge_tween: Tween
	if sprite:
		charge_tween = create_tween().set_parallel(true)
		charge_tween.tween_property(sprite, "scale", original_sprite_scale * Vector2(1.35, 1.45), false_telegraph_duration).set_trans(Tween.TRANS_SINE)
		charge_tween.tween_property(sprite, "position:y", initial_sprite_pos.y - 25.0, false_telegraph_duration)

	var elapsed: float = 0.0
	var flash_timer: float = 0.0

	while elapsed < false_telegraph_duration:
		await get_tree().physics_frame
		if is_dead:
			if charge_tween and charge_tween.is_valid():
				charge_tween.kill()
			return

		var dt: float = get_physics_process_delta_time()
		elapsed += dt
		flash_timer += dt

		var progress: float = clampf(elapsed / false_telegraph_duration, 0.0, 1.0)
		var shake_intensity: float = lerpf(2.0, 9.0, progress)
		global_position = initial_pos + Vector2(randf_range(-shake_intensity, shake_intensity), randf_range(-shake_intensity, shake_intensity))
		_apply_arena_screen_shake(shake_intensity * 0.75)

		var flash_rate: float = lerpf(0.2, 0.05, progress)
		if flash_timer >= flash_rate:
			flash_timer = 0.0
			_flash_custom(Color(1.0, 0.9, 0.2, 1.0) if randf() > 0.5 else Color.WHITE, 0.6)

	if charge_tween and charge_tween.is_valid():
		charge_tween.kill()

	global_position = initial_pos
	_apply_arena_screen_shake(0.0)
	if is_dead:
		return

	var will_fail: bool = randf() < fail_chance if has_fired_first_barrage else false
	has_fired_first_barrage = true

	if will_fail:
		await _execute_false_telegraph_fail(initial_sprite_pos)
	else:
		await _execute_false_telegraph_barrage(initial_sprite_pos)


func _execute_false_telegraph_fail(initial_sprite_pos: Vector2) -> void:
	current_state = State.FALSE_TELEGRAPH_FAIL
	_flash_custom(Color(0.4, 0.4, 0.4, 1.0), 1.0)

	if sprite:
		var pop_down: Tween = create_tween().set_parallel(true)
		pop_down.tween_property(sprite, "scale", original_sprite_scale * Vector2(1.1, 0.7), 0.08)
		pop_down.tween_property(sprite, "position", initial_sprite_pos, 0.08)
		await pop_down.finished
		var restore: Tween = create_tween()
		restore.tween_property(sprite, "scale", original_sprite_scale, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(stun_confused_duration, false).timeout
	if not is_dead:
		_finish_attack_to_idle(true)


func _execute_false_telegraph_barrage(initial_sprite_pos: Vector2) -> void:
	current_state = State.FALSE_TELEGRAPH_BARRAGE
	_flash_custom(Color(1.0, 0.2, 0.2, 1.0), 1.0)
	_apply_arena_screen_shake(6.0)

	if sprite:
		var shoot_tween: Tween = create_tween().set_parallel(true)
		shoot_tween.tween_property(sprite, "scale", original_sprite_scale, 0.15)
		shoot_tween.tween_property(sprite, "position", initial_sprite_pos, 0.15)

	await _fire_barrage_fan()
	_apply_arena_screen_shake(0.0)
	if not is_dead:
		_finish_attack_to_idle(true)


func _fire_barrage_fan() -> void:
	if not projectile_scene:
		return

	var spawn_pos: Vector2 = _get_projectile_spawn_pos()
	var base_direction: Vector2 = Vector2.LEFT if sprite.flip_h else Vector2.RIGHT
	if player:
		base_direction = spawn_pos.direction_to(player.global_position)

	var base_angle: float = base_direction.angle()
	var spread_rad: float = deg_to_rad(barrage_spread_angle)
	var half_spread_rad: float = spread_rad * 0.5

	for wave in range(barrage_waves):
		if is_dead:
			return
		var wave_angle_offset: float = deg_to_rad(randf_range(-8.0, 8.0))

		for i in range(projectiles_per_wave):
			var t: float = float(i) / float(projectiles_per_wave - 1) if projectiles_per_wave > 1 else 0.5
			var angle: float = (base_angle - half_spread_rad) + (t * spread_rad) + wave_angle_offset
			var is_danger: bool = randf() < dangerous_projectile_chance
			var proj_color: Color = dangerous_color if is_danger else fake_colors.pick_random()

			_spawn_moving_projectile(spawn_pos, Vector2.from_angle(angle), randf_range(380.0, 520.0), is_danger, proj_color)

		await get_tree().create_timer(0.12, false).timeout


# --- GOLPE 4: QUEBRA DE FREIO INIBITÓRIO ---

func start_inhibitory_break_sequence() -> void:
	velocity = Vector2.ZERO
	current_state = State.INHIBITORY_BREAK_SLOW_PREP

	if player:
		burst_direction = signf(player.global_position.x - global_position.x)
		if burst_direction == 0.0:
			burst_direction = 1.0
		flip_sprite(burst_direction)
	else:
		burst_direction = -1.0 if sprite.flip_h else 1.0

	var initial_sprite_pos: Vector2 = sprite.position if sprite else Vector2.ZERO
	var current_telegraph_time: float = randf_range(min_telegraph_time, max_telegraph_time)

	var windup_tween: Tween = create_tween().set_parallel(true)
	if sprite:
		windup_tween.tween_property(sprite, "position:x", initial_sprite_pos.x - (burst_direction * 22.0), current_telegraph_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		windup_tween.tween_property(sprite, "scale", original_sprite_scale * Vector2(0.85, 1.2), current_telegraph_time)

	await get_tree().create_timer(current_telegraph_time, false).timeout
	if is_dead:
		return

	if windup_tween.is_valid():
		windup_tween.kill()

	_flash_custom(Color(1.0, 0.3, 0.1, 1.0), 1.0)
	_apply_arena_screen_shake(3.5)

	if sprite:
		var snap_tween: Tween = create_tween()
		snap_tween.tween_property(sprite, "position", initial_sprite_pos, 0.05)
		snap_tween.tween_property(sprite, "scale", original_sprite_scale * Vector2(1.35, 0.75), 0.06)

	await get_tree().create_timer(0.06, false).timeout
	_apply_arena_screen_shake(0.0)
	if is_dead:
		return

	current_state = State.INHIBITORY_BREAK_BURST
	_play_animation_safe("dash")

	var burst_timer: float = 0.0
	while burst_timer < burst_dash_duration:
		burst_timer += get_process_delta_time()
		if is_dead:
			return
		if is_on_wall():
			break
		await get_tree().process_frame

	velocity.x = 0.0
	if sprite:
		var restore_tween: Tween = create_tween()
		restore_tween.tween_property(sprite, "scale", original_sprite_scale, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_finish_attack_to_idle(true)


# --- GOLPE 5: PÊNDULO IMPULSIVO ---

func _start_whirlwind_prep() -> void:
	velocity.x = 0.0
	_apply_arena_screen_shake(2.0)
	_play_animation_safe("prep_explosion")

	for i in range(3):
		_flash_custom(Color(1.0, 0.5, 0.0, 1.0), 1.0)
		await get_tree().create_timer(0.25).timeout
		if is_dead:
			return

	whirlwind_center_x = (arena_bounds_min.x + arena_bounds_max.x) * 0.5
	whirlwind_amplitude = whirlwind_amplitude_start
	whirlwind_current_speed = whirlwind_start_speed

	var start_dir: float = 1.0 if randf() > 0.5 else -1.0
	whirlwind_target_x = whirlwind_center_x + (start_dir * whirlwind_amplitude)
	current_state = State.WHIRLWIND_SWEEP


func _execute_whirlwind_explosion() -> void:
	velocity = Vector2.ZERO
	var pre_explosion_time: float = 1.0
	var elapsed: float = 0.0
	var initial_pos: Vector2 = global_position
	var target_y: float = initial_pos.y - 150.0

	_play_animation_safe("prep_explosion")

	while elapsed < pre_explosion_time:
		elapsed += get_process_delta_time()
		if is_dead:
			return

		var progress: float = clampf(elapsed / pre_explosion_time, 0.0, 1.0)
		var ease_progress: float = 1.0 - pow(1.0 - progress, 3.0)
		var current_base_pos: Vector2 = Vector2(initial_pos.x, lerpf(initial_pos.y, target_y, ease_progress))

		var shake_intensity: float = lerpf(1.0, 14.0, progress * progress)
		global_position = current_base_pos + Vector2(randf_range(-shake_intensity, shake_intensity), randf_range(-shake_intensity, shake_intensity))
		_apply_arena_screen_shake(shake_intensity * 0.6)

		if randf() < progress * 0.4:
			_flash_custom(Color(1.0, 0.4, 0.0, 1.0), 0.6)

		await get_tree().process_frame

	global_position = Vector2(initial_pos.x, target_y)
	_apply_arena_screen_shake(10.0)
	_flash_custom(Color(1.0, 0.1, 0.1, 1.0), 1.0)
	_play_animation_safe("explosion")

	_fire_whirlwind_explosion()
	_apply_arena_screen_shake(0.0)

	await get_tree().create_timer(0.6).timeout
	if not is_dead:
		_finish_attack_to_idle()


func _fire_whirlwind_explosion() -> void:
	if not projectile_scene:
		return

	var spawn_pos: Vector2 = _get_projectile_spawn_pos()
	var angle_step: float = TAU / float(whirlwind_projectiles)

	for i in range(whirlwind_projectiles):
		if is_dead:
			return
		var dir: Vector2 = Vector2.from_angle(angle_step * float(i))
		_spawn_moving_projectile(spawn_pos, dir, randf_range(380.0, 550.0), true, dangerous_color)


# ==============================================================================
# UTILITÁRIOS E FEEDBACK VISUAL
# ==============================================================================

func flash() -> void:
	_flash_custom(Color.WHITE, 1.0, 0.15)


func _flash_custom(color: Color, modifier: float = 1.0, duration: float = 0.08) -> void:
	if not sprite or not sprite.material:
		return

	var mat: ShaderMaterial = sprite.material as ShaderMaterial
	if not mat:
		return

	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()

	mat.set_shader_parameter("flash_color", color)
	mat.set_shader_parameter("flash_modifier", modifier)

	_flash_tween = create_tween()
	_flash_tween.tween_property(mat, "shader_parameter/flash_modifier", 0.0, duration)
	_flash_tween.tween_callback(func() -> void:
		if is_instance_valid(mat):
			mat.set_shader_parameter("flash_color", Color.WHITE)
	)


func _apply_arena_screen_shake(intensity: float) -> void:
	if not is_inside_tree():
		return
	var viewport: Viewport = get_viewport()
	if not is_instance_valid(viewport):
		return

	var canvas_transform: Transform2D = viewport.canvas_transform
	canvas_transform.origin = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity)) if intensity > 0.0 else Vector2.ZERO
	viewport.canvas_transform = canvas_transform


func _spawn_moving_projectile(spawn_pos: Vector2, dir: Vector2, proj_speed: float, is_danger: bool, color: Color) -> void:
	var proj: Node = projectile_scene.instantiate()
	get_parent().add_child(proj)
	if proj.has_method("setup_moving"):
		proj.setup_moving(spawn_pos, dir, proj_speed, is_danger, color)


func _get_projectile_spawn_pos() -> Vector2:
	return ponto_de_tiro.global_position if ponto_de_tiro else global_position


func _get_whirlwind_progress() -> float:
	return 1.0 - clampf(whirlwind_amplitude / maxf(whirlwind_amplitude_start, 1.0), 0.0, 1.0)


func _face_player() -> void:
	if player:
		flip_sprite(signf(player.global_position.x - global_position.x))


func _finish_attack_to_idle(play_idle_anim: bool = false) -> void:
	current_state = State.IDLE
	if play_idle_anim:
		_play_animation_safe("idle")
	decision_timer.start(attack_cooldown)


func _play_animation_safe(anim_name: String) -> void:
	if anim and anim.has_animation(anim_name):
		anim.play(anim_name)


func _shake_entity_for_duration(duration: float, intensity: float) -> void:
	var timer: float = 0.0
	var initial_pos: Vector2 = global_position
	while timer < duration:
		timer += get_process_delta_time()
		if is_dead:
			return
		global_position = initial_pos + Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		await get_tree().process_frame
	global_position = initial_pos


func _reset_sprite_transform() -> void:
	if sprite:
		sprite.rotation = 0.0
		sprite.scale = original_sprite_scale
		sprite.position = base_sprite_pos
