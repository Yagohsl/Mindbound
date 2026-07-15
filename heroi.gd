extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -700.0

# Referencias aos nós de sprite e animacao
@onready var sprite = $Sprite2D
@onready var anim = $AnimationPlayer

var is_attacking = false
var is_dashing = false

func _physics_process(delta: float) -> void:
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
