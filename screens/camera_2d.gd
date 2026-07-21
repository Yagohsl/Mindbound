extends Camera2D

@export var player: Node2D
@export var boss: Node2D

@export var min_zoom: float = 0.7 # Zoom máximo de afastamento (visão geral)
@export var max_zoom: float = 1.5 # Zoom máximo de aproximação (luta corpo a corpo)
@export var margin: Vector2 = Vector2(300, 200) # Margem extra para os cantos da tela

func _process(_delta: float) -> void:
	# Previne erros caso um dos personagens seja derrotado ou removido da cena
	if not player or not boss:
		return
		
	# 1. Ajuste de Posição (Ponto Médio)
	var mid_point = (player.global_position + boss.global_position) / 2.0
	global_position = mid_point
	
	# 2. Ajuste de Zoom (Distância Base)
	var distance_x = abs(player.global_position.x - boss.global_position.x)
	var distance_y = abs(player.global_position.y - boss.global_position.y)
	
	var screen_size = get_viewport_rect().size
	
	# Calcula qual deveria ser o zoom para a largura e altura caberem na tela
	var zoom_x = screen_size.x / (distance_x + margin.x)
	var zoom_y = screen_size.y / (distance_y + margin.y)
	
	# Escolhe o menor zoom para garantir que ninguém saia da tela
	var target_zoom = min(zoom_x, zoom_y)
	
	# Limita o zoom entre os valores mínimo e máximo definidos
	target_zoom = clamp(target_zoom, min_zoom, max_zoom)
	
	# Aplica o zoom suavemente (opcional, usar lerp para suavizar a transição do zoom)
	zoom = zoom.lerp(Vector2(target_zoom, target_zoom), 2.0 * _delta)
