extends CharacterBody2D

# --- SINAIS ---
signal health_changed(new_health: int)

# --- CONFIGURAÇÕES DE MOVIMENTAÇÃO ---
@export_group("Movimento")
@export var speed: float = 300.0
@export var jump_velocity: float = -900.0
@export var gravity_multiplier: float = 1.8

@export_group("Dash")
@export var dash_speed: float = 800.0
@export var dash_duration: float = 0.3
@export var dash_cooldown_time: float = 1.0
@export var dash_recovery_time: float = 0.2

@export_group("Combate & Vida")
@export var max_health: int = 100
@export var attack_value: int = 98
@export var invincibility_time: float = 1.0
@export var knockback_duration: float = 0.18
@export var knockback_force: Vector2 = Vector2(620.0, -320.0)

# --- NÓS ---
@onready var sprite: Sprite2D = $Sprite2D
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var attack_collision: CollisionShape2D = $AttackHitbox/CollisionShape2D
@onready var attack = $Attack # Referência ao nó do impacto
# --- ESTADOS & VARIÁVEIS INTERNAS ---
var current_health: int = 100
var is_dead: bool = false
var is_attacking: bool = false
var is_dashing: bool = false
var is_invincible: bool = false
var is_dash_invincible: bool = false
var is_in_knockback: bool = false

# Efeitos de status
var is_slowed: bool = false
var is_paralyzed: bool = false
var is_trapped: bool = false
var slow_multiplier: float = 1.0

# Controles de tempo
var dash_time_left: float = 0.0
var dash_cooldown: float = 0.0

# Referências de Tweens para evitar conflitos visuais
var _flash_tween: Tween
var _status_tween: Tween


func _ready() -> void:
	current_health = max_health
	if attack_collision:
		attack_collision.disabled = true


func _physics_process(delta: float) -> void:
	# 1. Estados restritivos (Morte, Paralisia, Aprisionado)
	if is_dead or is_trapped or is_paralyzed:
		_apply_gravity(delta)
		if is_on_floor():
			velocity.x = 0.0
		move_and_slide()
		return

	# 2. Knockback ativo (preserva vetor de impacto)
	if is_in_knockback:
		_apply_gravity(delta)
		move_and_slide()
		return

	# 3. Temporizadores
	if dash_cooldown > 0.0:
		dash_cooldown -= delta

	# 4. Execução do Dash
	if is_dashing:
		dash_time_left -= delta
		if dash_time_left <= 0.0:
			velocity.x = 0.0
			is_dashing = false
			trigger_dash_recovery()
		move_and_slide()
		return

	# 5. Entrada do Dash
	if Input.is_action_just_pressed("dash") and not is_attacking and dash_cooldown <= 0.0:
		_start_dash()
		move_and_slide()
		return

	# 6. Gravidade padrão
	_apply_gravity(delta)

	# 7. Ações de Combate e Pulo
	if Input.is_action_just_pressed("attack") and not is_attacking:
		_start_attack()

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= 0.5

	# 8. Movimentação Horizontal e Animações
	_handle_movement()
	_update_air_animations()

	move_and_slide()


# --- FÍSICA & CONTROLE AUXILIAR ---

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += (get_gravity() * gravity_multiplier) * delta


func _handle_movement() -> void:
	var direction: float = Input.get_axis("move_left", "move_right")
	var target_speed: float = speed * slow_multiplier

	if direction != 0.0:
		velocity.x = direction * target_speed
		if not is_attacking:
			_set_facing_direction(direction < 0.0)
			if is_on_floor():
				anim.play("run")
	else:
		velocity.x = move_toward(velocity.x, 0.0, target_speed)
		if is_on_floor() and not is_attacking:
			anim.play("idle")


func _update_air_animations() -> void:
	if not is_on_floor() and not is_attacking:
		if velocity.y < 0.0:
			anim.play("jump_up")
		else:
			anim.play("jump_down")


func _set_facing_direction(facing_left: bool) -> void:
	sprite.flip_h = facing_left
	if attack_hitbox:
		attack_hitbox.scale.x = -1.0 if facing_left else 1.0
	if attack:
		attack.flip_h = facing_left
		attack.position.x = -abs(attack.position.x) if facing_left else abs(attack.position.x)


func _start_dash() -> void:
	is_dashing = true
	dash_time_left = dash_duration
	dash_cooldown = dash_cooldown_time

	var dash_dir: float = -1.0 if sprite.flip_h else 1.0
	velocity.x = dash_dir * dash_speed
	velocity.y = 0.0
	anim.play("dash")


func _start_attack() -> void:
	is_attacking = true
	anim.play("attack")


# --- COMBATE & DANO ---

func take_damage(amount: int, attacker_pos: Vector2 = Vector2.ZERO) -> void:
	if is_invincible or is_dashing or is_dash_invincible or is_dead:
		return

	current_health = maxi(0, current_health - amount)
	health_changed.emit(current_health)

	hitstop(0.08, 0.3)

	if attacker_pos != Vector2.ZERO:
		apply_knockback(attacker_pos)

	flash()

	if current_health <= 0:
		die()
	else:
		trigger_invincibility()


func apply_knockback(attacker_pos: Vector2) -> void:
	is_in_knockback = true
	var dir_x: float = signf(global_position.x - attacker_pos.x)
	if dir_x == 0.0:
		dir_x = -1.0 if sprite.flip_h else 1.0

	velocity.x = dir_x * knockback_force.x
	velocity.y = knockback_force.y

	await get_tree().create_timer(knockback_duration, false).timeout
	is_in_knockback = false


func trigger_invincibility() -> void:
	is_invincible = true
	flash()
	await get_tree().create_timer(invincibility_time, false).timeout
	is_invincible = false


func trigger_dash_recovery() -> void:
	is_dash_invincible = true
	await get_tree().create_timer(dash_recovery_time, false).timeout
	is_dash_invincible = false


func flash() -> void:
	if not sprite or not sprite.material:
		return

	# Mata tween ativo para não travar o shader no branco
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()

	_flash_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_flash_tween.tween_property(sprite.material, "shader_parameter/flash_modifier", 1.0, 0.0)
	_flash_tween.tween_property(sprite.material, "shader_parameter/flash_modifier", 0.0, 0.15)


func enable_attack_hitbox() -> void:
	if attack_collision:
		attack_collision.disabled = false


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "attack":
		is_attacking = false
		if attack_collision:
			attack_collision.disabled = true


func _on_attack_hitbox_body_entered(body: Node2D) -> void:
	if body != self and body.has_method("take_damage"):
		body.take_damage(attack_value, global_position)
		hitstop(0.05, 0.09)


func hitstop(time_factor: float = 0.05, duration: float = 0.08) -> void:
	Engine.time_scale = time_factor
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0


func die() -> void:
	Engine.time_scale = 1.0
	is_dead = true
	is_invincible = true

	if attack_collision:
		attack_collision.disabled = true
	
	# Interrompe qualquer animação de transição visual ativa
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	if _status_tween and _status_tween.is_valid():
		_status_tween.kill()

	if anim:
		anim.speed_scale = 1.0

	if sprite and sprite.material:
		sprite.material.set_shader_parameter("flash_modifier", 0.0)
		sprite.material.set_shader_parameter("slow_modifier", 0.0)

	modulate = Color.WHITE
	anim.play("death")

	await get_tree().create_timer(3.0, false, false, true).timeout
	if get_tree():
		get_tree().reload_current_scene()


# --- EFEITOS DE STATUS (SLOW, PARALYSIS, TRAP) ---

func apply_slow(factor: float, duration: float) -> void:
	if is_dead:
		return

	slow_multiplier = factor
	is_slowed = true

	if anim:
		anim.speed_scale = factor

	if sprite and sprite.material:
		if _status_tween and _status_tween.is_valid():
			_status_tween.kill()
		_status_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_status_tween.tween_property(sprite.material, "shader_parameter/slow_modifier", 1.0, 0.1)

	await get_tree().create_timer(duration, false).timeout

	slow_multiplier = 1.0
	is_slowed = false
	modulate = Color.WHITE

	if anim:
		anim.speed_scale = 1.0

	if sprite and sprite.material:
		var reset_tween: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		reset_tween.tween_property(sprite.material, "shader_parameter/slow_modifier", 0.0, 0.2)


func apply_paralysis(duration: float) -> void:
	if is_dead:
		return

	is_paralyzed = true
	velocity.x = 0.0

	if anim:
		anim.pause()
		
	turn_purple()
	await get_tree().create_timer(duration, false).timeout

	is_paralyzed = false
	if anim and not is_dead:
		anim.play()
	turn_white()


func trap_player() -> void:
	is_trapped = true
	velocity = Vector2.ZERO
	if anim:
		anim.play("idle")
	turn_purple()


func release_player() -> void:
	is_trapped = false
	is_paralyzed = false
	slow_multiplier = 1.0 # Garante que a velocidade não fique travada em zero
	
	if anim and not is_dead:
		anim.speed_scale = 1.0
		anim.play("idle")
		
	turn_white()
func turn_purple():
	if sprite and sprite.material:
		if _status_tween and _status_tween.is_valid():
			_status_tween.kill()
		_status_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_status_tween.tween_property(sprite.material, "shader_parameter/slow_modifier", 1.0, 0.1)

func turn_white():
	if sprite and sprite.material:
		var reset_tween: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		reset_tween.tween_property(sprite.material, "shader_parameter/slow_modifier", 0.0, 0.2)
