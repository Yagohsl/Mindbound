extends TextureProgressBar
class_name HeroHealthBar

const DEFAULT_BORDER_TEX: Texture2D = preload("res://assets/images/menu/health_border..png")
const DEFAULT_PROGRESS_TEX: Texture2D = preload("res://assets/images/menu/health_progress.png")
const DEFAULT_UNDER_TEX: Texture2D = preload("res://assets/images/menu/health_under.png")

# --- CONFIGURAÇÕES DE JUICE ---
@export_group("Damage Feedback")
@export var damage_delay: float = 0.4
@export var damage_decay_duration: float = 0.45
@export var normal_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var damage_bar_color: Color = Color(0.95, 0.45, 0.15, 1.0)

@export_group("Low Health Alert")
@export var low_health_threshold_ratio: float = 0.30
@export var low_health_color: Color = Color(1.0, 0.25, 0.25, 1.0)
@export var pulse_speed: float = 5.5

@export_group("Shake & Impact")
@export var max_shake_offset: float = 8.0
@export var shake_decay: float = 3.8
@export var enable_scale_punch: bool = true

# --- NÓS E VARIÁVEIS INTERNAS ---
@onready var damage_bar: TextureProgressBar = get_node_or_null("DamageBar")

var _base_position: Vector2 = Vector2.ZERO
var _shake_trauma: float = 0.0
var _is_low_health: bool = false
var _pulse_time: float = 0.0

var _health_tween: Tween
var _damage_tween: Tween
var _flash_tween: Tween
var _scale_tween: Tween
var _color_tween: Tween


func _ready() -> void:
	_setup_textures_and_damage_bar()
	call_deferred("_initialize_layout_and_hero")


func _initialize_layout_and_hero() -> void:
	_base_position = position
	pivot_offset = size * 0.5
	_auto_connect_to_hero()


func _setup_textures_and_damage_bar() -> void:
	if texture_over == null:
		texture_over = DEFAULT_BORDER_TEX
	if texture_progress == null:
		texture_progress = DEFAULT_PROGRESS_TEX

	if not damage_bar:
		damage_bar = TextureProgressBar.new()
		damage_bar.name = "DamageBar"
		damage_bar.show_behind_parent = true
		damage_bar.layout_mode = 1
		damage_bar.anchors_preset = Control.PRESET_FULL_RECT
		damage_bar.anchor_right = 1.0
		damage_bar.anchor_bottom = 1.0
		damage_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
		damage_bar.grow_vertical = Control.GROW_DIRECTION_BOTH
		damage_bar.nine_patch_stretch = true
		damage_bar.texture_under = texture_under if texture_under != null else DEFAULT_UNDER_TEX
		damage_bar.texture_progress = texture_progress
		texture_under = null
		add_child(damage_bar)

	damage_bar.tint_progress = damage_bar_color
	damage_bar.max_value = max_value
	damage_bar.value = value


func _auto_connect_to_hero() -> void:
	var hero: Node = get_tree().get_first_node_in_group("player")
	if not hero and owner:
		hero = owner.find_child("Heroi", true, false)
	if not hero:
		hero = get_node_or_null("../../StaticBody2D/Heroi")

	if hero:
		init_health(hero.current_health, hero.max_health)
		if not hero.health_changed.is_connected(set_health):
			hero.health_changed.connect(set_health)


func _process(delta: float) -> void:
	_handle_shake(delta)
	_handle_low_health_pulse(delta)


func init_health(current: float, maximum: float) -> void:
	max_value = maximum
	value = current

	if damage_bar:
		damage_bar.max_value = maximum
		damage_bar.value = current

	_check_low_health(current)


func set_health(new_health: float) -> void:
	var old_health: float = value
	var health_diff: float = new_health - old_health

	_check_low_health(new_health)

	if health_diff < 0.0:
		_on_damage_taken(new_health, absf(health_diff))
	elif health_diff > 0.0:
		_on_heal(new_health)
	else:
		value = new_health
		if damage_bar:
			damage_bar.value = new_health


func _on_damage_taken(new_health: float, damage_amount: float) -> void:
	_kill_tween(_health_tween)
	_health_tween = create_tween()
	_health_tween.tween_property(self, "value", new_health, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if damage_bar:
		_kill_tween(_damage_tween)
		_damage_tween = create_tween()
		_damage_tween.tween_interval(damage_delay)
		_damage_tween.tween_property(damage_bar, "value", new_health, damage_decay_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var relative_damage: float = damage_amount / maxf(max_value, 1.0)
	var added_trauma: float = clampf(0.5 + relative_damage * 1.5, 0.6, 1.5)
	_add_shake(added_trauma)

	if enable_scale_punch:
		_kill_tween(_scale_tween)
		_scale_tween = create_tween()
		_scale_tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_scale_tween.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	if new_health > 0.0:
		_flash_impact()


func _on_heal(new_health: float) -> void:
	_kill_tween(_health_tween)
	_kill_tween(_damage_tween)

	_health_tween = create_tween()
	_health_tween.tween_property(self, "value", new_health, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if damage_bar:
		damage_bar.value = new_health


func _flash_impact() -> void:
	_kill_tween(_flash_tween)
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "tint_progress", Color(2.0, 2.0, 2.0, 1.0), 0.05)

	var target_color: Color = low_health_color if _is_low_health else normal_color
	_flash_tween.tween_property(self, "tint_progress", target_color, 0.1)


func _add_shake(amount: float) -> void:
	_shake_trauma = clampf(_shake_trauma + amount, 0.0, 1.5)


func _handle_shake(delta: float) -> void:
	if _shake_trauma > 0.0:
		_shake_trauma = maxf(_shake_trauma - delta * shake_decay, 0.0)
		var shake_power: float = _shake_trauma * _shake_trauma
		var offset: Vector2 = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * max_shake_offset * shake_power
		position = _base_position + offset
	elif position != _base_position:
		position = _base_position


func _check_low_health(current: float) -> void:
	var ratio: float = current / maxf(max_value, 1.0)
	var was_low: bool = _is_low_health
	_is_low_health = ratio <= low_health_threshold_ratio and current > 0.0

	if not _is_low_health and was_low:
		_kill_tween(_color_tween)
		_color_tween = create_tween()
		_color_tween.tween_property(self, "tint_progress", normal_color, 0.3)
	elif current <= 0.0:
		_kill_tween(_flash_tween)
		tint_progress = low_health_color


func _handle_low_health_pulse(delta: float) -> void:
	if not _is_low_health:
		return
	if _flash_tween and _flash_tween.is_valid():
		return

	_pulse_time += delta * pulse_speed
	var pulse_factor: float = (sin(_pulse_time) + 1.0) * 0.5
	tint_progress = low_health_color.lerp(Color(1.0, 0.65, 0.65, 1.0), pulse_factor * 0.4)


func _kill_tween(tween: Tween) -> void:
	if tween and tween.is_valid():
		tween.kill()
