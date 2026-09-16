extends CanvasLayer

signal minigame_resolved(success: bool)

@onready var progress_bar = $ProgressBar
@onready var label = $Label

@export var max_progress: float = 100.0
@export var click_power: float = 15.0     # Quanto cada clique sobe a barra
@export var decay_rate: float = 35.0      # Queda da barra por segundo
@export var time_limit: float = 3.0       # Tempo máximo para escapar

var current_progress: float = 0.0
var time_left: float = 0.0
var is_active: bool = false

func _ready() -> void:
	visible = false

func start_minigame() -> void:
	current_progress = 20.0 # Começa com um empurrão inicial
	time_left = time_limit
	progress_bar.max_value = max_progress
	progress_bar.value = current_progress
	visible = true
	is_active = true

func _process(delta: float) -> void:
	if not is_active:
		return
		
	# A barra cai naturalmente com o tempo
	current_progress = max(0.0, current_progress - (decay_rate * delta))
	time_left -= delta
	progress_bar.value = current_progress
	
	# Condição de derrota (tempo esgotado)
	if time_left <= 0.0:
		finish(false)

func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return
		
	# Ao apertar o botão (ex: tecla de pulo/interação/espaço)
	if event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		current_progress += click_power
		progress_bar.value = current_progress
		
		# Feedback de escala suave na barra ao apertar
		var tween = create_tween()
		tween.tween_property(progress_bar, "scale", Vector2(1.05, 1.05), 0.04)
		tween.tween_property(progress_bar, "scale", Vector2(1.0, 1.0), 0.04)
		
		# Condição de vitória (resistiu aos pensamentos)
		if current_progress >= max_progress:
			finish(true)

func finish(success: bool) -> void:
	is_active = false
	visible = false
	minigame_resolved.emit(success)
	queue_free()
