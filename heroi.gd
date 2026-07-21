extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -700.0

const DASH_SPEED = 800.0
const DASH_DURATION = 0.2 # tempo em segundos do dash

# Referencias aos nós de sprite e animacao
@onready var sprite = $Sprite2D
@onready var anim = $AnimationPlayer
@onready var attack_hitbox = $AttackHitbox
@onready var attack_collision = $AttackHitbox/CollisionShape2D # Certifique-se de que o CollisionShape2D seja filho direto da AttackHitbox

signal health_changed(new_health)
var max_health = 100
var current_health = 100
var attack_value = 15

var is_attacking = false
var is_dashing = false
var dash_time_left = 0.0
var dash_cooldown = 0.0
var is_invincible: bool = false
@export var invincibility_time: float = 1.0

func _ready() -> void:
	# Garante que a hitbox começa desativada para não causar dano à toa
	if attack_collision:
		attack_collision.disabled = true

func _physics_process(delta: float) -> void:
	
	if dash_cooldown > 0:
		dash_cooldown -= delta
		
	# ativa o dash
	if Input.is_action_just_pressed("dash") and not is_dashing and not is_attacking and dash_cooldown <= 0:
		is_dashing = true
		dash_time_left = DASH_DURATION
		dash_cooldown = 1.0
		
		var dash_dir = -1 if sprite.flip_h else 1
		velocity.x = dash_dir * DASH_SPEED
		velocity.y = 0
		anim.play("dash")
	
	# executa o dash
	if is_dashing:
		dash_time_left -= delta
		if dash_time_left <= 0:
			velocity.x = 0
			is_dashing = false
		move_and_slide()
		return

	# Ataque
	if Input.is_action_just_pressed("attack") and not is_attacking and is_on_floor():
		is_attacking = true
		velocity.x = 0 # Para o movimento ao atacar (dá mais firmeza ao combate 2D)
		anim.play("attack")
		return # Interrompe o resto do _physics_process durante o frame inicial do ataque

	# Se estiver atacando, segura o player e processa apenas a gravidade/slide
	if is_attacking:
		if not is_on_floor():
			velocity += get_gravity() * delta
		velocity.x = move_toward(velocity.x, 0, SPEED)
		move_and_slide()
		return

	# Adiciona a gravidade.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Pulo.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	# Amortecimento de pulo
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= 0.5

	# Movimentacao
	var direction := Input.get_axis("move_left", "move_right")
	if direction:
		velocity.x = direction * SPEED
		
		# Vira o player e a hitbox de ataque junto
		sprite.flip_h = direction < 0
		if direction < 0:
			attack_hitbox.scale.x = -1 # vira pra esquerda
		else:
			attack_hitbox.scale.x = 1 # vira pra direita
			
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

func take_damage(amount):
	if is_invincible:
		return
	current_health -= amount
	health_changed.emit(current_health)
	
	if current_health <= 0:
		die()
	else:
		trigger_invincibility()

func trigger_invincibility():
	is_invincible = true
	flash()
	# espera o tempo de invencibilidade acabar
	await get_tree().create_timer(invincibility_time).timeout
	is_invincible = false
	
func flash():
	var mat = sprite.material
	if mat:
		var tween = create_tween()
		tween.tween_property(mat, "shader_parameter/flash_modifier", 1.0, 0.0)
		tween.tween_property(mat, "shader_parameter/flash_modifier", 0.0, 0.15)


func enable_attack_hitbox():
	if attack_collision:
		attack_collision.disabled = false

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "attack":
		is_attacking = false
		if attack_collision:
			attack_collision.disabled = true # Desativa a hitbox ao fim do ataque

func _on_attack_hitbox_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage") and body != self:
		body.take_damage(attack_value)
		# Opcional: desativar a hitbox após acertar o primeiro golpe para evitar dano múltiplo no mesmo swing
		if attack_collision:
			attack_collision.disabled = true

func die():
	set_physics_process(false)
	anim.play("death")
