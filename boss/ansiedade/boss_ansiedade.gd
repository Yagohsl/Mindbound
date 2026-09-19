extends CharacterBody2D

# --- Mapeamento de Estados ---
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

signal health_changed(new_health: int)

# --- Configurações de Atributos e Vida ---
@export_group("Atributos Básicos")
@export var max_health: int = 300
@export var current_health: int = 300
@export var attack_value: int = 15
@export var speed: float = 150.0
@export var stop_distance: float = 160.0

@export_group("Dificuldade Dinâmica (Cooldowns)")
@export var max_attack_cooldown: float = 1.5
@export var min_attack_cooldown: float = 0.3
@export var attack_cooldown: float = 1.5

@export_group("Ataque: Dash")
@export var dash_speed: float = 500.0
@export var dash_max_distance: float = 500.0
@export var max_dash_prep: float = 0.7
@export var min_dash_prep: float = 0.1

@export_group("Ataque: Teleporte")
@export var max_teleport_wait: float = 1.0
@export var min_teleport_wait: float = 0.2
@export var min_teleport_distance: float = 250.0
@export var min_player_teleport_distance: float = 110.0

@export_group("Referências de Cena e Recursos")
@export var player: Node2D
@export var projectile_scene: PackedScene
@export var teleport_warning_scene: PackedScene
@export var player_icon: Texture2D
@export var boss_icon: Texture2D

# --- Nós Filhos ---
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D
@onready var decision_timer: Timer = $DecisionTimer
@onready var damage_area: Area2D = $DamageArea
@onready var ponto_de_tiro: Marker2D = $PontoDeTiro

# --- Variáveis de Controle Interno ---
var current_state: State = State.IDLE
var is_dead: bool = false
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

var current_dash_prep: float = 0.7
var current_teleport_wait: float = 1.0
var dash_direction: int = 0
var dash_distance_left: float = 0.0
var contact_damage_cooldown: float = 0.0

# Diálogos
var dialogos_inicio: Array[Dictionary] = []
var dialogos_vitoria: Array[Dictionary] = []


func _ready() -> void:
	current_health = max_health
	current_dash_prep = max_dash_prep
	current_teleport_wait = max_teleport_wait

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
	


func _physics_process(delta: float) -> void:
	if current_state == State.DEATH:
		if not is_on_floor():
			velocity.y += gravity * delta
		else:
			velocity.y = 0.0
		
		velocity.x = 0.0 # Impede que continue deslizando para os lados
		move_and_slide()
		return

	# Gravidade
	if not is_on_floor() and current_state != State.TELEPORT:
		velocity.y += gravity * delta

	# Dano por contato contínuo protegido por cooldown
	if contact_damage_cooldown > 0.0:
		contact_damage_cooldown -= delta
	else:
		_process_contact_damage()

	# Execução da FSM
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

			# Desaceleração nos últimos 25% do percurso
			if progress_ratio < 0.25:
				var ease_t: float = progress_ratio / 0.25
				current_speed = lerp(min_dash_speed, dash_speed, ease_t)

			var step: float = current_speed * delta
			velocity.x = dash_direction * current_speed
			dash_distance_left -= step

			if is_on_wall():
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
			velocity.x = 0.0
			if player:
				flip_sprite(sign(player.global_position.x - global_position.x))

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
				if dash_direction == 0:
					dash_direction = 1
				flip_sprite(dash_direction)

			anim.play("prep_dash")
			await get_tree().create_timer(current_dash_prep).timeout
			if current_state == State.DEATH: return

			dash_distance_left = dash_max_distance
			current_state = State.DASH


func fire_preoccupation() -> void:
	if not projectile_scene or not player:
		return
		
	var spawn_pos: Vector2 = ponto_de_tiro.global_position if ponto_de_tiro else global_position
	var proj = projectile_scene.instantiate()
	proj.global_position = spawn_pos
	get_parent().add_child(proj)

	var angle: float = spawn_pos.direction_to(player.global_position).angle() + randf_range(-0.2, 0.2)
	proj.setup(angle, 500.0)


func fire_explosion() -> void:
	if not projectile_scene:
		return

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
		if current_state == State.DEATH:
			return

		global_position = target_pos
		teleports_done += 1

		if teleports_done < 3:
			await get_tree().create_timer(0.3, false, false, true).timeout
			if current_state == State.DEATH:
				return


func flip_sprite(dir: float) -> void:
	if dir != 0:
		sprite.flip_h = (dir < 0)


func take_damage(amount: int) -> void:
	if current_state == State.DEATH:
		return

	current_health = clampi(current_health - amount, 0, max_health)
	health_changed.emit(current_health)

	var porcentagem_vida: float = float(current_health) / float(max_health)
	attack_cooldown = lerp(min_attack_cooldown, max_attack_cooldown, porcentagem_vida)
	current_dash_prep = lerp(min_dash_prep, max_dash_prep, porcentagem_vida)
	current_teleport_wait = lerp(min_teleport_wait, max_teleport_wait, porcentagem_vida)

	flash()
	if current_health <= 0:
		die()


func flash() -> void:
	if not sprite.material:
		return
	var mat = sprite.material
	var tween: Tween = create_tween()
	tween.tween_property(mat, "shader_parameter/flash_modifier", 1.0, 0.0)
	tween.tween_property(mat, "shader_parameter/flash_modifier", 0.0, 0.15)


func die() -> void:
	is_dead = true
	current_state = State.DEATH
	velocity.x = 0.0
	decision_timer.stop()
	anim.play("death")
