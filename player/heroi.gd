extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -900.0
const GRAVITY_MULTIPLIER = 1.8

const DASH_SPEED = 800.0
const DASH_DURATION = 0.3 # tempo em segundos do dash

# Referencias aos nós de sprite e animacao
@onready var sprite = $Sprite2D
@onready var anim = $AnimationPlayer
@onready var attack_hitbox = $AttackHitbox
@onready var attack_collision = $AttackHitbox/CollisionShape2D # Certifique-se de que o CollisionShape2D seja filho direto da AttackHitbox

signal health_changed(new_health)
var max_health = 100
var current_health = 100
var attack_value = 8
var is_dead: bool = false

var is_attacking = false
var is_dashing = false
var dash_time_left = 0.0
var dash_cooldown = 0.0
var is_invincible: bool = false
@export var invincibility_time: float = 1.0
var is_in_knockback: bool = false
@export var knockback_duration: float = 0.18 # Duração do recuo em segundos

var is_dash_invincible: bool = false
@export var dash_recovery_time: float = 0.2 # 200 milissegundos extras de invencibilidade

func _ready() -> void:
	# Garante que a hitbox começa desativada para não causar dano à toa
	if attack_collision:
		attack_collision.disabled = true

func _physics_process(delta: float) -> void:
	if is_trapped:
		if not is_on_floor():
			velocity += (get_gravity() * GRAVITY_MULTIPLIER) * delta
		else:
			velocity.x = 0
		move_and_slide()
		return

	if is_paralyzed:
		if not is_on_floor():
			velocity += (get_gravity() * GRAVITY_MULTIPLIER) * delta
		else:
			velocity.x = 0
		move_and_slide()
		return

	if is_dead:
		if not is_on_floor():
			velocity += (get_gravity() * GRAVITY_MULTIPLIER) * delta 
		else:
			velocity.x = 0
		move_and_slide()
		return

	# Gravidade (sempre aplicada fora dos estados especiais)
	if not is_on_floor():
		velocity += (get_gravity() * GRAVITY_MULTIPLIER) * delta

	# Cooldown do dash
	if dash_cooldown > 0:
		dash_cooldown -= delta

	# Execução do dash
	if is_dashing:
		dash_time_left -= delta
		if dash_time_left <= 0:
			velocity.x = 0
			is_dashing = false
			trigger_dash_recovery()
		move_and_slide()
		return

	# Se estiver em knockback, pula o controle de inputs para manter a inércia do impacto
	if is_in_knockback:
		move_and_slide()
		return

	# Ativa o dash
	if Input.is_action_just_pressed("dash") and not is_dashing and not is_attacking and dash_cooldown <= 0:
		is_dashing = true
		dash_time_left = DASH_DURATION
		dash_cooldown = 1.0
		
		var dash_dir = -1 if sprite.flip_h else 1
		velocity.x = dash_dir * DASH_SPEED
		velocity.y = 0
		anim.play("dash")
		move_and_slide()
		return

	# Ataque
	if Input.is_action_just_pressed("attack") and not is_attacking:
		is_attacking = true
		anim.play("attack")

	# Pulo
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Amortecimento de pulo
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= 0.5

	# Movimentação Horizontal
	var direction := Input.get_axis("move_left", "move_right")
	if direction:
		velocity.x = direction * (SPEED * slow_multiplier)

		if not is_attacking:
			sprite.flip_h = direction < 0
			if direction < 0:
				attack_hitbox.scale.x = -1
			else:
				attack_hitbox.scale.x = 1

		if is_on_floor() and not is_attacking:
			anim.play("run")
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * slow_multiplier)
		if is_on_floor() and not is_attacking:
			anim.play("idle")

	# Controle de animação aérea
	if not is_on_floor() and not is_attacking:
		if velocity.y < 0:
			anim.play("jump_up")
		else:
			anim.play("jump_down")

	move_and_slide()

func take_damage(amount, attacker_pos: Vector2 = Vector2.ZERO):
	if is_invincible or is_dashing or is_dash_invincible or is_dead:
		return
	current_health -= amount
	health_changed.emit(current_health)
	
	hitstop(0.08, 0.3)
	
	# Aplica o Knockback
	if attacker_pos != Vector2.ZERO:
		apply_knockback(attacker_pos)
	
	flash()
	if current_health <= 0:
		die()
	else:
		trigger_invincibility()

func apply_knockback(attacker_pos: Vector2) -> void:
	is_in_knockback = true
	
	var dir_x = sign(global_position.x - attacker_pos.x)
	if dir_x == 0:
		dir_x = -1 if sprite.flip_h else 1
		
	velocity.x = dir_x * 620.0  # Força horizontal
	velocity.y = -320.0        # Leve elevação vertical
	
	await get_tree().create_timer(knockback_duration).timeout
	is_in_knockback = false
	
	
func trigger_invincibility():
	is_invincible = true
	flash()
	# espera o tempo de invencibilidade acabar
	await get_tree().create_timer(invincibility_time).timeout
	is_invincible = false
	
func flash():
	var mat = sprite.material
	if mat:
		var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
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
		hitstop(0.05, 0.09) # Desacelera drasticamente o tempo por ~90 milissegundos
		
func trigger_dash_recovery():
	is_dash_invincible = true
	await get_tree().create_timer(dash_recovery_time).timeout
	is_dash_invincible = false
	
	

func die():
	Engine.time_scale = 1.0
	is_dead = true
	is_invincible = true
	set_physics_process(false)
	
	if anim:
		anim.speed_scale = 1.0
	
	if sprite.material and sprite:
		sprite.material.set_shader_parameter("flash_modifier", 0.0)
		sprite.material.set_shader_parameter("slow_modifier", 0.0)
	
	anim.play("death")
	await get_tree().create_timer(3.0, false, false, true).timeout
	
	# Verificação de segurança: checa se a árvore ainda existe antes de recarregar
	if get_tree():
		get_tree().reload_current_scene()
# LENTIDAO
var slow_multiplier: float = 1.0
var is_slowed: bool = false

func apply_slow(factor: float, duration: float) -> void:
	
	slow_multiplier = factor
	is_slowed = true
	if anim:
		anim.speed_scale = factor
		
	# Feedback visual: escurece ou tinge o sprite de roxo/cinza
	if sprite and sprite.material:
		var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(sprite.material, "shader_parameter/slow_modifier", 1.0, 0.1)
	await get_tree().create_timer(duration).timeout
	
	# Retorna aos valores normais
	slow_multiplier = 1.0
	is_slowed = false
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	if anim:
		anim.speed_scale = 1.0
		
	if sprite and sprite.material:
		var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(sprite.material, "shader_parameter/slow_modifier", 0.0, 0.2)


var is_paralyzed: bool = false

func apply_paralysis(duration: float) -> void:
	if is_dead:
		return
		
	is_paralyzed = true
	velocity.x = 0
	
	# Feedback visual: congela a animação e aplica tom escuro/preso
	if anim:
		anim.pause()
	if sprite:
		modulate = Color(0.3, 0.2, 0.4, 1.0)
	
	await get_tree().create_timer(duration).timeout
	
	# Restaura o estado normal
	is_paralyzed = false
	if anim:
		anim.play()
	if sprite:
		modulate = Color(1.0, 1.0, 1.0, 1.0)

var is_trapped: bool = false

func trap_player() -> void:
	is_trapped = true
	velocity = Vector2.ZERO
	if anim:
		anim.play("idle")
	# Tinge o herói com uma cor escura/pesada
	modulate = Color(0.4, 0.2, 0.5, 1.0)

func release_player() -> void:
	is_trapped = false
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	
# time_factor: velocidade do tempo (0.05 a 0.1 cria a desaceleração quase total)
# duration: duração do efeito em segundos reais (0.06 a 0.12 segundos é a média do gênero)
func hitstop(time_factor: float = 0.05, duration: float = 0.08) -> void:
	Engine.time_scale = time_factor
	# O 4º parâmetro (true) ignora o time_scale para o temporizador correr no tempo real da vida real
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
