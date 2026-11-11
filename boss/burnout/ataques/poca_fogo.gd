extends Area2D

@export var damage_per_tick: int = 8
@export var damage_interval: float = 0.55
@export var fire_duration: float = 4.5
@export var telegraph_radius: float = 38.0

@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var fire_sprite: Node2D = get_node_or_null("FireSprite")
@onready var fire_particles: CPUParticles2D = get_node_or_null("FireParticles")

var is_telegraphing: bool = false
var is_active: bool = false
var is_extinguishing: bool = false

var telegraph_duration: float = 1.15
var telegraph_elapsed: float = 0.0
var telegraph_progress: float = 0.0
var damage_tick_timer: float = 0.0

func _ready() -> void:
	add_to_group("burnout_hazards")
	# Começa desativado durante o aviso no chão
	if collision:
		collision.disabled = true
	if fire_sprite:
		fire_sprite.visible = false
	if fire_particles:
		fire_particles.emitting = false

func setup_telegraph(target_pos: Vector2, flight_time: float) -> void:
	global_position = target_pos
	telegraph_duration = maxf(flight_time, 0.1)
	telegraph_elapsed = 0.0
	telegraph_progress = 0.0
	is_telegraphing = true
	is_active = false
	queue_redraw()

func ignite() -> void:
	if is_active or is_extinguishing:
		return
		
	is_telegraphing = false
	is_active = true
	damage_tick_timer = 0.0
	queue_redraw()
	
	if collision:
		collision.set_deferred("disabled", false)
		
	if fire_sprite:
		fire_sprite.visible = true
		if fire_sprite is AnimatedSprite2D:
			fire_sprite.play("burn")
	if fire_particles:
		fire_particles.emitting = true
		
	await get_tree().create_timer(fire_duration, false).timeout
	if not is_instance_valid(self) or is_extinguishing:
		return
	_extinguish()

func _physics_process(delta: float) -> void:
	if is_telegraphing:
		telegraph_elapsed += delta
		telegraph_progress = clampf(telegraph_elapsed / telegraph_duration, 0.0, 1.0)
		queue_redraw()
		return
		
	if not is_active or is_extinguishing:
		return
		
	# Redesenha apenas se estiver usando o fogo procedural (sem sprite/partículas)
	if not fire_sprite and not fire_particles:
		queue_redraw()
		
	damage_tick_timer = maxf(damage_tick_timer - delta, 0.0)
	if damage_tick_timer <= 0.0:
		for body in get_overlapping_bodies():
			if body.is_in_group("player"):
				if body.has_method("take_damage"):
					body.take_damage(damage_per_tick, global_position)
				damage_tick_timer = damage_interval
				break

func _draw() -> void:
	if is_telegraphing:
		# Achatado no eixo Y para parecer um círculo em perspectiva no chão 2D
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, telegraph_radius, Color(1.0, 0.2, 0.05, 0.22))
		draw_arc(Vector2.ZERO, telegraph_radius, 0.0, TAU, 32, Color(1.0, 0.35, 0.1, 0.9), 2.5)
		
		var inner_radius: float = telegraph_radius * telegraph_progress
		draw_circle(Vector2.ZERO, inner_radius, Color(1.0, 0.45, 0.05, 0.4))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif is_active and not fire_sprite and not fire_particles:
		# Visual provisório caso ainda não tenha adicionado o sprite do fogo
		var flicker: float = sin(Time.get_ticks_msec() * 0.02) * 3.0
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, telegraph_radius, Color(1.0, 0.3, 0.0, 0.75))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_circle(Vector2(-12.0, -10.0 + flicker * 0.4), 10.0, Color(1.0, 0.55, 0.1, 0.85))
		draw_circle(Vector2(10.0, -12.0 - flicker * 0.4), 12.0, Color(1.0, 0.4, 0.05, 0.85))
		draw_circle(Vector2(0.0, -16.0 + flicker * 0.6), 13.0, Color(1.0, 0.75, 0.15, 0.9))

func _extinguish() -> void:
	is_extinguishing = true
	is_active = false
	if collision:
		collision.set_deferred("disabled", true)
	if fire_particles:
		fire_particles.emitting = false
		
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	if is_instance_valid(self):
		queue_free()

func force_cleanup() -> void:
	if not is_extinguishing:
		_extinguish()
