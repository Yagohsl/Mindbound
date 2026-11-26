extends CanvasLayer

# --- SINAIS ---
signal minigame_resolved(success: bool)

# --- CONFIGURAÇÕES EXPORTADAS ---
@export var max_progress: float = 100.0
@export var click_power: float = 15.0
@export var decay_rate: float = 35.0
@export var time_limit: float = 3.0

# --- REFERÊNCIAS DE NÓS (@onready) ---
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var label: Label = $Label

# --- VARIÁVEIS INTERNAS ---
var current_progress: float = 0.0
var time_left: float = 0.0
var is_active: bool = false
var _scale_tween: Tween = null


# --- MÉTODOS NATIVOS ---
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	visible = false
	if progress_bar:
		progress_bar.pivot_offset = progress_bar.size / 2.0


func _process(delta: float) -> void:
	if not is_active:
		return

	current_progress = maxf(0.0, current_progress - (decay_rate * delta))
	time_left -= delta
	if progress_bar:
		progress_bar.value = current_progress

	if time_left <= 0.0:
		finish(false)


func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return

	if event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		current_progress += click_power
		if progress_bar:
			progress_bar.value = current_progress

			if _scale_tween and _scale_tween.is_valid():
				_scale_tween.kill()

			_scale_tween = create_tween()
			_scale_tween.tween_property(progress_bar, "scale", Vector2(1.05, 1.05), 0.04)
			_scale_tween.tween_property(progress_bar, "scale", Vector2(1.0, 1.0), 0.04)

		if current_progress >= max_progress:
			finish(true)


# --- MÉTODOS PÚBLICOS ---
func start_minigame() -> void:
	current_progress = 20.0
	time_left = time_limit
	if progress_bar:
		progress_bar.pivot_offset = progress_bar.size / 2.0
		progress_bar.max_value = max_progress
		progress_bar.value = current_progress
	visible = true
	is_active = true


func finish(success: bool) -> void:
	if not is_active:
		return
	is_active = false
	visible = false
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
	minigame_resolved.emit(success)
	queue_free()
