extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0

# Mapeamento de Estados
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
signal health_changed(new_health)
var current_state = State.IDLE
var max_health = 150
var current_health = 150
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
var dialogos_derrota: Array[Dictionary] = []

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
	
	dialogos_derrota = [
		{"icone": boss_icon, "texto": "Eu avisei. O medo e a exaustão assumiram o controle total."},
		{"icone": player_icon, "texto": "Está tudo tão confuso... Eu não consigo pensar direito."},
		{"icone": player_icon, "texto": "Dar um passo para trás não é o fim. Reconhecer que precisa de ajuda ou de um descanso também é parte do processo de cura. Respire e tente novamente."}
	]
func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	
	move_and_slide()
