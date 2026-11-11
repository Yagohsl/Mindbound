extends Area2D

@export var impact_damage: int = 12
@export var damage_while_falling: bool = true
@export var spin_speed: float = 10.0

@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var sprite: Node2D = get_node_or_null("Sprite2D")
@onready var trail_particles: CPUParticles2D = get_node_or_null("TrailParticles")

var start_pos: Vector2 = Vector2.ZERO
var target_pos: Vector2 = Vector2.ZERO
var flight_time: float = 1.15
var arc_height: float = 280.0
var elapsed: float = 0.0
var is_initialized: bool = false
var has_landed: bool = false
var linked_puddle: Node2D = null

func _ready() -> void:
	add_to_group("burnout_hazards")
	if collision:
		collision.disabled = true
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func setup(p_start_pos: Vector2, p_target_pos: Vector2, p_flight_time: float, p_arc_height: float, p_puddle: Node2D = null) -> void:
	start_pos = p_start_pos
	target_pos = p_target_pos
	flight_time = maxf(p_flight_time, 0.1)
	arc_height = p_arc_height
	linked_puddle = p_puddle
	global_position = start_pos
	elapsed = 0.0
	is_initialized = true
	has_landed = false
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not is_initialized or has_landed:
		return
		
	elapsed += delta
	var t: float = clampf(elapsed / flight_time, 0.0, 1.0)
	
	# Arco parabólico exato: começa em start_pos, sobe até arc_height e cai em target_pos
	var base_pos: Vector2 = start_pos.lerp(target_pos, t)
	var arc_offset: float = 4.0 * arc_height * t * (1.0 - t)
	global_position = base_pos - Vector2(0.0, arc_offset)
	
	if sprite:
		sprite.rotation += spin_speed * delta
	else:
		queue_redraw()
		
	# Só ativa colisão na segunda metade da queda para não punir o player perto do boss na subida
	if collision:
		collision.disabled = (not damage_while_falling) or (t < 0.6)
		
	if t >= 1.0:
		_on_land()

func _draw() -> void:
	# Fallback visual caso ainda não haja Sprite2D configurado
	if not sprite:
		draw_circle(Vector2.ZERO, 9.0, Color(1.0, 0.3, 0.05, 1.0))
		draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.85, 0.25, 1.0))

func _on_body_entered(body: Node2D) -> void:
	if not damage_while_falling or has_landed:
		return
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(impact_damage, global_position)

func _on_land() -> void:
	has_landed = true
	if collision:
		collision.set_deferred("disabled", true)
	if sprite:
		sprite.visible = false
	queue_redraw()
	
	if is_instance_valid(linked_puddle) and linked_puddle.has_method("ignite"):
		linked_puddle.ignite()
		
	# Aguarda o rastro de partículas desaparecer suavemente antes de remover da memória
	if trail_particles:
		trail_particles.emitting = false
		await get_tree().create_timer(trail_particles.lifetime, false).timeout
		
	if is_instance_valid(self):
		queue_free()

func force_cleanup() -> void:
	if is_instance_valid(self):
		queue_free()
