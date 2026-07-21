extends Area2D

var velocity: Vector2 = Vector2.ZERO
var wave_speed: float = 0.0
var wave_amplitude: float = 0.0
var time_alive: float = 0.0
var base_y: float = 0.0

@export var damage: int = 5

func setup(angle: float, speed: float):
	# Calcula a velocidade inicial com base no ângulo
	velocity = Vector2(cos(angle), sin(angle)) * speed
	wave_speed = randf_range(10.0, 18.0)
	
	# Na Godot, como a tela costuma ser maior ou a física funciona diferente,
	# pode ser necessário aumentar a amplitude.
	wave_amplitude = randf_range(20.0, 50.0) 

func _ready():
	# Salva o Y original para a onda senoidal não distorcer a rota
	base_y = global_position.y

func _process(delta):
	time_alive += delta
	
	# Efeito ondulatório
	var wave = sin(time_alive * wave_speed) * wave_amplitude
	
	global_position.x += velocity.x * delta
	base_y += velocity.y * delta
	global_position.y = base_y + wave
	
	# Destrói o projétil se sair da tela
	if global_position.x < -50 or global_position.x > 1330 or global_position.y < -50 or global_position.y > 770:
		queue_free()

# Conecte este sinal usando a aba "Node" ao lado do "Inspector"
func _on_body_entered(body):
	if body.is_in_group("player"):
		# Corrigido de 'dashing' para 'is_dashing'
		if body.has_method("take_damage") and not body.is_dashing:
			body.take_damage(damage)
			queue_free() # Some ao acertar
