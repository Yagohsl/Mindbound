extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0

# Mapeamento de Estados
enum State {
	IDLE,
	PROJECTILE,
	GEISER_PREP,
	GEISER,
	BAD_THOUGHTS_PREP,
	BAD_THOUGHTS,
	RAIN,
	ATTACK,
	DEATH
}
signal health_changed(new_health)
var current_state = State.IDLE
var max_health = 450
var current_health = 450
var attack_value = 15
var is_dead = false

# Variaveis de atributos
@export var speed = 150.0
@export var dash_speed: float = 400.0 #velocidade dash
@export var health: int = 150
@export var player: Node2D #referencia ao player
@export var projectile_scene: PackedScene #arrasta a cena do projetil no inspetor
@export var teleport_warning_scene: PackedScene
@export var attack_cooldown: float = 2.0

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

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
	# execucao da maquina de estados
	match current_state:
		State.IDLE:
			anim.play("idle")
			velocity.x = move_toward(velocity.x, 0, speed)

	if current_state in [State.IDLE]:
		move_and_slide()
		
	
	# gravidade
	if not is_on_floor():
		velocity.y += gravity * delta
	
	var bodies = damage_area.get_overlapping_bodies()
	for body in bodies:
		body.take_damage(attack_value)
	
	move_and_slide()

# Estrutura de ataque na Máquina de Estados
func execute_attack_sequence() -> void:
	match current_state:
		State.PROJECTILE:
			velocity.x = 0
			anim.play("attack") # Altere para o nome da sua animação de disparo
			fire_lodo()
			
			await anim.animation_finished
			current_state = State.IDLE
			decision_timer.start(attack_cooldown)

func _on_decision_timer_timeout() -> void:
	if current_state != State.IDLE:
		return
	decision_timer.stop()
	
	# Inclua o State.PROJETCILE na lista de escolhas da IA
	var choices = [State.PROJECTILE] 
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


func take_damage(amount):
	if current_state == State.DEATH:
		return
	current_health -= amount
	health_changed.emit(current_health)
	
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
	if not is_dead and body.has_method("take_damage") and body !=self:
		body.take_damage(attack_value)
