extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -700.0

const DASH_SPEED = 800.0
const DASH_DURATION = 0.2 # tempo em segundos do dash

# Referencias aos nós de sprite e animacao
@onready var sprite = $Sprite2D
@onready var anim = $AnimationPlayer
@onready var attack_hitbox = $AttackHitbox

signal health_changed(new_health)
var max_health = 100
var current_health = 100
var attack_value = 15

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
	

		
	# Ataque
	if Input.is_action_just_pressed("attack") and not is_attacking:
		is_attacking = true
		anim.play("attack")
	
	
	# Adiciona a gravidade.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Pulo.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	# Amortecimento de pulo
	if Input.is_action_just_released("jump") and velocity.y <0:
		velocity.y *= 0.5

	# Movimentacao
	# Pega a entrada (direta ou esquerda) e lida com a movementacao
	var direction := Input.get_axis("move_left", "move_right")
	if direction:
		velocity.x = direction * SPEED
		
		# Vira o player
		if not is_attacking:
			sprite.flip_h = direction < 0
			if direction < 0:
				attack_hitbox.scale.x = -1 # vira pra esquera
			else:
				attack_hitbox.scale.x = 1 # vira pra direita
			
		# Toca anim de correr se estiver no chao e nao atacando
		if is_on_floor() and not is_attacking:
			anim.play("run")
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		
		if is_on_floor() and not is_attacking:
			anim.play("idle")
	
	# Controle de anim aerea
	if not is_on_floor() and not is_attacking:
		if velocity.y < 0:
			anim.play("jump_up")
		else:
			anim.play("jump_down")

	move_and_slide()

func take_damage(amount):
	current_health -= amount
	
	health_changed.emit(current_health)
	# Hit
	flash()
	
	if current_health <=0:
		die()
	
func flash():
	var mat = sprite.material

	var tween = create_tween()
	
	tween.tween_property(mat, "shader_parameter/flash_modifier", 1.0, 0.0)
	tween.tween_property(mat, "shader_parameter/flash_modifier", 0.0, 0.15)
	

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "attack":
		is_attacking = false

func _on_attack_hitbox_body_entered(body: Node2D) -> void:
	
	if body.has_method("take_damage") and body != self:
		body.take_damage(attack_value) 

func die():
	set_physics_process(false) # para de se mexer
	anim.play("death")
