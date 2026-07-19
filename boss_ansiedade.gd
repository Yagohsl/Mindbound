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

# Variaveis de atributos
@export var speed = 150.0
@export var dash_speed: float = 400.0 #velocidade dash
@export var health: int = 150
@export var player: Node2D #referencia ao player
@export var projectile_scene: PackedScene #arrasta a cena do projetil no inspetor

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var anim = $AnimationPlayer
@onready var sprite = $Sprite2D
@onready var decision_timer = $DecisionTimer

# var de controle de ataques
var dash_direction: int = 0
var dash_distance_left: float = 0.0
var dash_max_distance: float = 500.0
var min_teleport_distance: float = 250.0

func _physics_process(delta: float) -> void:
	if current_state == State.DEATH:
		return
	
	# gravidade
	if not is_on_floor() and current_state != State.TELEPORT:
		velocity.y += gravity * delta
	
	# execucao da maquina de estados
	match current_state:
		State.IDLE:
			anim.play("idle")
			velocity.x = move_toward(velocity.x, 0, speed)
		
		State.RUN:
			if player:
				var dir = sign(player.global_position.x - global_position.x)
				velocity.x = dir * speed
				flip_sprite(dir)
			anim.play("run")
		
		State.DASH:
			anim.play("dash")
			var step = dash_speed * delta
			velocity.x = dash_direction * dash_speed
			dash_distance_left -= step
				
			if dash_distance_left <= 0:
				velocity.x = 0
				current_state = State.IDLE
				decision_timer.start() # reinicia a IA

	if current_state in [State.IDLE, State.RUN, State.DASH]:
		move_and_slide()
		
# Logica da IA
func _on_decision_timer_timeout():
	if current_state != State.IDLE and current_state != State.RUN:
		return
	
	# decide proximo ataque
	var choices = [State.RUN, State.DASH_PREP, State.THOUGHTS, State.EXPLOSION_PREP, State.TELEPORT]
	current_state = choices [randi() % choices.size()]
	execute_attack_sequence()
	

func execute_attack_sequence():
	match current_state:
		State.THOUGHTS:
			velocity.x = 0
			anim.play("projectile")
			fire_preoccupation()
			await anim.animation_finished # espera a animacao acabar
			current_state = State.IDLE
		
		State.EXPLOSION_PREP:
			velocity.x = 0
			anim.play("prep_explosion")
			await get_tree().create_timer(0.5).timeout
			
			current_state = State.EXPLOSION
			anim.play("explosion")
			fire_explosion()
			await get_tree().create_timer(0.4).timeout
			
			current_state = State.IDLE
		
		State.TELEPORT:
			velocity = Vector2.ZERO
			anim.play("explosion")
			await teleport_routine()
			
		State.DASH_PREP:
			velocity.x = 0
			anim.play("prep_dash")
			await get_tree().create_timer(0.5).timeout
			
			if player:
				dash_direction = sign(player.global_position.x - global_position.x)
				if dash_direction == 0: dash_direction = 1
			dash_distance_left = dash_max_distance
			current_state = State.DASH
	
func fire_preoccupation():
	if not projectile_scene or not player:return
	var proj = projectile_scene.instantiate()
	get_parent().add_child(proj)
	proj.global_position = global_position
	
	# angulo irregular
	var angle = global_position.direction_to(player.global_position).angle() + randf_range(-0.2, 0.2)
	proj.setup(angle, 300.0) # inicia o projetil

func fire_explosion():
	if not projectile_scene: return
	var num_projectiles = 12
	for i in range(num_projectiles):
		var proj = projectile_scene.instantiate()
		get_parent().add_child(proj)
		proj.global_position = global_position
		var angle = (2 * PI / num_projectiles) * 1
		proj.setup(angle, 250.0)

func teleport_routine():
	var teleports_done = 0
	while teleports_done < 3:
		var rand_x = randf_range(100,1180)
		while abs(rand_x - global_position.x) <min_teleport_distance:
			rand_x = randf_range(100,1180)
		var rand_y = randf_range(200, 500)
		var target_pos = Vector2(rand_x, rand_y)
		
		await get_tree().create_timer(0.7).timeout
		
		global_position = target_pos
		teleports_done += 1
		
		if teleports_done <3:
			await get_tree().create_timer(0.3).timeout
	current_state = State.IDLE

func flip_sprite(dir):
	sprite.flip_h = (dir < 0)

func take_damage(amount):
	current_health -= amount
	health_changed.emit(current_health)
	
	# Hit
	flash()
	if current_health<=0:
		die()
	
func flash():
	var mat = sprite.material

	var tween = create_tween()
	
	tween.tween_property(mat, "shader_parameter/flash_modifier", 1.0, 0.0)
	tween.tween_property(mat, "shader_parameter/flash_modifier", 0.0, 0.15)
	
func die():
	current_state = State.DEATH
	velocity = Vector2.ZERO
	anim.play("death")
	
func _on_damage_area_body_entered(body: CharacterBody2D) -> void:
	if current_state != State.DEATH and body.has_method("take_damage") and body !=self:
		body.take_damage(attack_value)
