extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0

# Mapeamento de Estados
enum State {
	IDLE,
	RUN,
	THOUGHTS,
	TELEPORT,
	DASH_PREP,
	DASH,
	DEAD
}
var current_state = State.IDLE

# Variaveis de atributos
@export var speed = 150.0
@export var rush_speed = 300.0 #velocidade dash
@export var jump_velocity = -400.0
@export var player_target: Node2D #referencia ao player

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var anim = $AnimationPlayer
@onready var sprite = $Sprite2D

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return
	
	# gravidade
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# execucao da maquina de estados
	match current_state:
		State.IDLE:
			anim.play("idle")
			velocity.x = move_toward(velocity.x, 0, speed)
		
		State.RUN:
			anim.play("run")
			var direction = sign(player_target.global_position.x - global_position.x)
			velocity.x = direction * rush_speed
			flip_sprite(direction)
		
		State.DASH_PREP:
			anim.play("dash_prep")
			velocity.x = 0
		State.DASH:
			anim.play("dash")
			var direction = sign(player_target.global_position.x - global_position.x)
			velocity.x = direction * (rush_speed * 2)

	move_and_slide()

# Logica da IA
func _on_decision_timer_timmeout():
	if current_state in [State.DEAD, State.DASH_PREP, State.DASH]:
		return
	decide_next_action()

func decide_next_action():
	var distance_to_player = abs(player_target.global_position.x - global_position.x)
	
	if distance_to_player > 300:
		# Se o player estiver longe, joga projeteis
		var choices = [State.THOUGHTS, State.DASH_PREP, State.RUN]
		current_state = choices[randi() % choices.size()]
	else:
		# Se estiver perto
		var choices = [State.TELEPORT, State.RUN]
		current_state = choices[randi() % choices.size()]
	
	if current_state == State.THOUGHTS:
		fire_projectiles()
		
func fire_projectiles():
	anim.play("projectlie")
	pass
func flip_sprite(direction):
	if direction < 0:
		sprite.flip_h = true
	elif direction > 0:
		sprite.flip_h = false
