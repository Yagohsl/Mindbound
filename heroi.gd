extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -700.0

const DASH_SPEED = 800.0
const DASH_DURATION = 0.2 # tempo em segundos do dash

# Referencias aos nós de sprite e animacao
@onready var sprite = $Sprite2D
@onready var anim = $AnimationPlayer

var is_attacking = false
var is_dashing = false
var dash_time_left = 0.0 # controla o tempo do dash
var dash_cooldown = 0.0

func _physics_process(delta: float) -> void:
	
	if dash_cooldown > 0:
		dash_cooldown -= delta
	# ativa o dash
	if Input.is_action_just_pressed("dash") and not is_dashing and not is_attacking and dash_cooldown <= 0:
		is_dashing = true
		dash_time_left = DASH_DURATION
		dash_cooldown = 1.0
		
		# direcao do dash (1 = direita, -1 = esquerda)
		var dash_dir = -1 if sprite.flip_h else 1
		velocity.x = dash_dir * DASH_SPEED
		velocity.y = 0
		anim.play("dash")
	
	# executa o dash
	if is_dashing:
		dash_time_left -= delta
		if dash_time_left <=0:
			velocity.x = 0
			is_dashing = false
		move_and_slide()
		return
	
	# Se estiver atacando ou dando dash, ignora o movimento normal
	if is_attacking or is_dashing:
		move_and_slide()
		return
		
	# Adiciona a gravidade.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Pulo.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	# Amortecimento de pulo
	if Input.is_action_just_released("jump") and velocity.y <0:
		velocity.y *= 0.5

	# Pega a entrada (direta ou esquerda) e lida com a movementacao
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("move_left", "move_right")
	if direction:
		velocity.x = direction * SPEED
		# Vira o player
		sprite.flip_h = direction < 0
		
		# Toca anim de correr se estiver no chao
		if is_on_floor():
			anim.play("run")
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		
		if is_on_floor():
			anim.play("idle")
	
	# Controle de anim aerea
	if not is_on_floor():
		if velocity.y < 0:
			anim.play("jump_up")
		else:
			anim.play("jump_down")

	move_and_slide()
