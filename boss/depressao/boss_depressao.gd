extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0

# Mapeamento de Estados
enum State {
	IDLE,
	RUN,
	PROJECTILE,
	GEISER_PREP,
	GEISER,
	BAD_THOUGHTS_PREP,
	BAD_THOUGHTS,
	MINIGAME,
	RAIN,
	ATTACK,
	DEATH
}
var damage_cooldown: float = 0.0
signal health_changed(new_health)
var current_state = State.IDLE
var max_health = 100
var current_health = 100
var attack_value = 15
var is_dead = false

# Variaveis de atributos
@export var speed = 50.0
@export var dash_speed: float = 400.0 #velocidade dash
@export var player: Node2D #referencia ao player
@export var projectile_scene: PackedScene 
@export var geiser_scene: PackedScene 
@export var tear_scene: PackedScene     
@export var minigame_scene: PackedScene 
@export var attack_cooldown: float = 2.0

# --- ATAQUE GEISER ---
@export var geiser_spacing: float = 250.0 # Distância horizontal uniforme entre cada poça
@export var min_geiser_count: int = 1   # Quantidade com 100% de vida
@export var max_geiser_count: int = 4   # Quantidade máxima perto de 0% de vida
var current_geiser_count: int = 1       # Variável dinâmica lida no ataque

@export var walk_duration: float = 2.0
var walk_direction: int = 1 # 1 para direita, -1 para esquerda

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# --- ATAQUE CHUVA DE LÁGRIMAS ---
@export var rain_drops_count: int = 14   # Quantidade de lágrimas disparadas
@export var rain_spawn_y: float = -40.0  # Altura no topo da tela onde as gotas surgem
@export var arena_min_x: float = 80.0    # Limite esquerdo da arena
@export var arena_max_x: float = 1200.0  # Limite direito da arena

# --- ATAQUE MINIGAME ---
@export var rush_speed: float = 650.0   # Velocidade do avanço rápido
@export var smash_heavy_damage: int = 40 # Dano alto se falhar
var rush_direction: int = 0
var rush_duration: float = 0.45
var player_caught: bool = false


@onready var anim = $AnimationPlayer
@onready var sprite = $Sprite2D
@onready var decision_timer = $DecisionTimer
@onready var damage_area = $DamageArea
@onready var ponto_de_tiro = $PontoDeTiro 


# var de controle de ataques
var dash_direction: int = 0
var dash_distance_left: float = 0.0
var dash_max_distance: float = 500.0
var min_teleport_distance: float = 250.0


@onready var dialog_box = $DialogBox

@export var player_icon: Texture2D
@export var boss_icon: Texture2D

var dialogos_inicio: Array[Dictionary] = []
var dialogos_vitoria: Array[Dictionary] = []
##var dialogos_derrota: Array[Dictionary] = []

func _ready() -> void:
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
	
	##dialogos_derrota = [
	##	{"icone": boss_icon, "texto": "Eu avisei. O medo e a exaustão assumiram o controle total."},
	##	{"icone": player_icon, "texto": "Está tudo tão confuso... Eu não consigo pensar direito."},
	##	{"icone": player_icon, "texto": "Dar um passo para trás não é o fim. Reconhecer que precisa de ajuda ou de um descanso também é parte do processo de cura. Respire e tente novamente."}
	##]
func _physics_process(delta: float) -> void:
	if current_state == State.DEATH:
		return

	# Gravidade
	if not is_on_floor():
		velocity.y += gravity * delta

	# Diminui o cooldown de dano de contato com o tempo
	if damage_cooldown > 0.0:
		damage_cooldown -= delta

	# Execução da máquina de estados
	match current_state:
		State.IDLE:
			anim.play("idle")
			velocity.x = move_toward(velocity.x, 0, speed)
		State.RUN:
			if is_on_wall():
				walk_direction *= -1
				flip_sprite(walk_direction)
			velocity.x = walk_direction * speed
			anim.play("idle")
		State.GEISER_PREP, State.GEISER, State.PROJECTILE, State.RAIN, State.MINIGAME:
			velocity.x = 0
	# Detecção de acerto do avanço rápido (Pensamentos Ruins)
	if current_state == State.BAD_THOUGHTS and not player_caught:
		var bodies = damage_area.get_overlapping_bodies()
		for body in bodies:
			if body.is_in_group("player") and body != self:
				trigger_thoughts_minigame(body)
				break

	# Dano de contato normal (apenas fora do minigame e respeitando o cooldown)
	if not player_caught and current_state not in [State.BAD_THOUGHTS_PREP, State.BAD_THOUGHTS, State.MINIGAME]:
		if damage_cooldown <= 0.0:
			var bodies = damage_area.get_overlapping_bodies()
			for body in bodies:
				if body.is_in_group("player") and body != self and body.has_method("take_damage"):
					body.take_damage(attack_value)
					damage_cooldown = 1.0 # Garante 1 segundo de intervalo entre hits de contato

	if current_state in [State.IDLE, State.RUN, State.BAD_THOUGHTS]:
		move_and_slide()
		
# Estrutura de ataque na Máquina de Estados
func execute_attack_sequence() -> void:
	match current_state:
		State.PROJECTILE:
			velocity.x = 0
			anim.play("attack") # Altere para o nome da sua animação de disparo
			fire_lodo()
			
			await anim.animation_finished
			if current_state == State.DEATH: return
			
			await walk_then_idle()
			
		State.GEISER_PREP:
			velocity.x = 0
			if anim.has_animation("prep_geiser"):
				anim.play("prep_geiser")
			
			# Espelha o boss na direção do player durante a preparação
			if player:
				flip_sprite(player.global_position.x - global_position.x)
			
			# Tempo de canalização/carregamento da animação
			await get_tree().create_timer(0.6).timeout
			if current_state == State.DEATH: return
			
			# Transiciona diretamente para o golpe
			current_state = State.GEISER
			execute_attack_sequence()

		# 2. Execução do Golpe (Spawna a poça/jato no chão)
		State.GEISER:
			velocity.x = 0
			if anim.has_animation("attack_geiser"):
				anim.play("attack_geiser")

			
			# Spawna a entidade do Gêiser no chão
			spawn_geiser()
			
			# Aguarda a animação do boss terminar antes de voltar ao IDLE
			if anim.is_playing() and anim.current_animation in ["attack_geiser"]:
				await anim.animation_finished
			else:
				await get_tree().create_timer(0.5).timeout
				
			if current_state == State.DEATH: return
			
			await walk_then_idle()
		State.RAIN:
			velocity.x = 0
			anim.play("cast_rain")
			
			# Executa a invocação aleatória das gotas
			await start_tear_rain()
			if current_state == State.DEATH: return
			
			# Anda aleatoriamente antes de voltar para IDLE
			await walk_then_idle()
		
		State.BAD_THOUGHTS_PREP:
			velocity.x = 0
			anim.play("prep_rush")
			
			# Vira em direção ao jogador antes de avançar
			if player:
				rush_direction = sign(player.global_position.x - global_position.x)
				flip_sprite(rush_direction)
			
			# Telegraph do golpe rápido
			await get_tree().create_timer(0.4).timeout
			if current_state == State.DEATH: return
			
			player_caught = false
			current_state = State.BAD_THOUGHTS
			execute_attack_sequence()

		State.BAD_THOUGHTS:
			anim.play("rush")
			# Avança rapidamente em linha reta
			velocity.x = rush_direction * rush_speed
			
			var elapsed = 0.0
			while elapsed < rush_duration:
				if player_caught or current_state == State.DEATH or is_on_wall():
					break
				elapsed += get_process_delta_time()
				await get_tree().process_frame
			
			velocity.x = 0
			
			# Se o player não foi pego, ele desvia e o boss apenas se recupera
			if not player_caught and current_state != State.MINIGAME:
				await get_tree().create_timer(0.3).timeout
				if current_state == State.DEATH: return
				await walk_then_idle()
				
func _on_decision_timer_timeout() -> void:
	if current_state != State.IDLE:
		return
	decision_timer.stop()
	
	# Inclua o State.PROJETCILE na lista de escolhas da IA
	var choices = [ State.BAD_THOUGHTS_PREP] 
	current_state = choices.pick_random()
	execute_attack_sequence()
	
# Função que instancia e direciona o projétil
func fire_lodo() -> void:
	if not projectile_scene or not player: return
		
	var proj = projectile_scene.instantiate()
	var spawn_pos = ponto_de_tiro.global_position if has_node("PontoDeTiro") else global_position
	
	proj.global_position = spawn_pos
	get_parent().add_child(proj)
	
	# Calcula a direção exata até o centro do player
	var dir = spawn_pos.direction_to(player.global_position)
	proj.setup(dir)
	
	# Espelha o boss na direção do disparo
	flip_sprite(dir.x)

func spawn_geiser() -> void:
	if not geiser_scene or not player:
		return
		
	var count = current_geiser_count
	var center_x = player.global_position.x
	var ground_y = global_position.y
	
	# Calcula a posição X inicial para distribuir igualmente em volta do jogador
	var total_width = (count - 1) * geiser_spacing
	var start_x = center_x - (total_width / 2.0)
	
	for i in range(count):
		var geiser = geiser_scene.instantiate()
		var pos_x = start_x + (i * geiser_spacing)
		
		geiser.global_position = Vector2(pos_x, ground_y)
		get_parent().add_child(geiser)
	

func start_tear_rain() -> void:
	if not tear_scene:
		return
		
	for i in range(rain_drops_count):
		if current_state == State.DEATH:
			return
			
		var drop = tear_scene.instantiate()
		var rand_x = randf_range(arena_min_x, arena_max_x)
		
		# Define a posição antes de adicionar à cena para evitar spawn no (0,0)
		drop.global_position = Vector2(rand_x, rain_spawn_y)
		get_parent().add_child(drop)
		
		# Intervalo entre uma lágrima e outra para cair em sequência
		await get_tree().create_timer(0.2).timeout

func trigger_thoughts_minigame(target_player: CharacterBody2D) -> void:
	player_caught = true
	current_state = State.MINIGAME # Trava o estado para não reativar outro ataque
	velocity.x = 0
	
	if target_player.has_method("trap_player"):
		target_player.trap_player()
	
	if not minigame_scene:
		if target_player.has_method("release_player"):
			target_player.release_player()
		player_caught = false
		await walk_then_idle()
		return
		
	var minigame = minigame_scene.instantiate()
	get_parent().add_child(minigame)
	minigame.start_minigame()
	
	# Aguarda o jogador vencer ou perder
	var success = await minigame.minigame_resolved
	
	if target_player.has_method("release_player"):
		target_player.release_player()
		
	if not success:
		# Player perdeu o minigame: recebe dano massivo
		if target_player.has_method("take_damage"):
			target_player.take_damage(smash_heavy_damage)
	else:
		# Player venceu: pequeno recuo (knockback) no Boss
		velocity.x = -rush_direction * 250.0
		
	damage_cooldown = 1.2
	player_caught = false
	
	if current_state == State.DEATH: return
	await walk_then_idle()

func walk_then_idle(duration: float = walk_duration) -> void:
	if current_state == State.DEATH:
		return
	walk_direction = [-1, 1].pick_random()
	flip_sprite(walk_direction)
	
	await get_tree().create_timer(0.6).timeout
	current_state = State.RUN

	# Anda pelo tempo configurado
	await get_tree().create_timer(duration).timeout
	
	# Trava de segurança: se ele morreu durante a caminhada, não executa o IDLE
	if current_state == State.DEATH:
		return
		
	# Para e inicia a contagem para o próximo golpe
	velocity.x = 0
	current_state = State.IDLE
	decision_timer.start(attack_cooldown)

func take_damage(amount):
	if current_state == State.DEATH:
		return
	current_health -= amount
	health_changed.emit(current_health)
	
	# --- DIFICULDADE PROGRESSIVA DINÂMICA ---
	# 1. Calcula a porcentagem atual de vida (de 0.0 a 1.0)
	var porcentagem_vida = float(current_health) / float(max_health)
	
	# 2. Ajusta dinamicamente a quantidade de poças (1 com vida cheia -> 4 com vida zerada)
	# Usamos roundi() ou int() para arredondar o valor interpolado para inteiro
	current_geiser_count = roundi(lerp(float(max_geiser_count), float(min_geiser_count), porcentagem_vida))
	current_geiser_count = clampi(current_geiser_count, min_geiser_count, max_geiser_count)
	
	# Hit
	if current_health<=0:
		die()
	
func flip_sprite(dir):
	sprite.flip_h = (dir < 0)

func die():
	is_dead = true
	current_state = State.DEATH
	velocity = Vector2.ZERO
	anim.play("death")
	
func _on_damage_area_body_entered(body: CharacterBody2D) -> void:
	if is_dead or player_caught or current_state in [State.BAD_THOUGHTS, State.MINIGAME]:
		return
	if damage_cooldown <= 0.0 and body.has_method("take_damage") and body != self and body.is_in_group("player"):
		body.take_damage(attack_value)
		damage_cooldown = 1.0
