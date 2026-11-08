extends BossBase

enum State {
	IDLE,
	RUN,
	SOOT_CLOUD,
	DEATH
}

@export_group("Arena Bounds")
@export var arena_min_x: float = 120.0
@export var arena_max_x: float = 1160.0

@export_group("Ataques")
@export var soot_cloud_scene: PackedScene


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
	if not is_instance_valid(player):
		var heroes = get_tree().get_nodes_in_group("player")
		if heroes.size() > 0:
			player = heroes[0]
		elif get_parent():
			player = get_parent().get_node_or_null("Heroi")
	
	if decision_timer:
		decision_timer.start(randf_range(1.5, 3.0))


func _physics_process(delta: float) -> void:
	if current_state == State.DEATH:
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
			if anim and anim.has_animation("idle"):
				anim.play("idle")
				
		State.RUN:
			if is_on_wall():
				walk_direction *= -1
				flip_sprite(walk_direction)
			elif is_instance_valid(player):
				var diff_x: float = signf(player.global_position.x - global_position.x)
				if abs(diff_x) > 12.0:
					walk_direction = int(signf(diff_x))
					flip_sprite(walk_direction)
					
			velocity.x = walk_direction * speed
			if anim and anim.has_animation("run"):
				anim.play("run")
				
		State.SOOT_CLOUD:
			velocity.x = move_toward(velocity.x, 0.0, speed)
	
	move_and_slide()

func execute_attack_sequence() -> void:
	match current_state:
		State.SOOT_CLOUD:
			velocity.x = 0.0
			if anim and anim.has_animation("soot_cloud"):
				anim.play("soot_cloud")
			elif anim and anim.has_animation("attack"):
				anim.play("attack")
			
			spawn_soot_cloud()
			
			await get_tree().create_timer(1.2).timeout
			if current_state == State.DEATH: return
			
			current_state = State.IDLE
			var cooldown_time : float = maxf(attack_cooldown, 0.5)
			if decision_timer:
				decision_timer.start(cooldown_time)

func spawn_soot_cloud():
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

func _on_decision_timer_timeout() -> void:
	if current_state not in [State.IDLE, State.RUN]:
		return
	decision_timer.stop()
	
	if current_state == State.RUN:
		current_state = State.SOOT_CLOUD
		execute_attack_sequence()
		return
	
	var choices = [State.RUN, State.SOOT_CLOUD]
	current_state = choices.pick_random()
	
	if current_state == State.RUN:
		decision_timer.start(randf_range(2.0, 4.0))
	else:
		execute_attack_sequence()
		
	

func flip_sprite(dir: float) -> void:
	if dir == 0.0:
		return
	sprite.flip_h = (dir < 0.0)
	if damage_collision:
		damage_collision.position.x = -abs(damage_collision.position.x) if dir < 0.0 else abs(damage_collision.position.x)
	if shoot_point:
		shoot_point.position.x = -abs(shoot_point.position.x) if dir < 0.0 else abs(shoot_point.position.x)

func _apply_dynamic_difficulty(life_percent: float) -> void:
	#burnout fica mais rapido e agressivo conforme sua vida diminui
	if life_percent < 0.4:
		speed = 185.0
	elif life_percent < 0.7:
		speed = 165.0

func _on_death() -> void:
	current_state = State.DEATH
	if decision_timer:
		decision_timer.stop()
