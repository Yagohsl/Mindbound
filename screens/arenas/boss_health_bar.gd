extends TextureProgressBar
class_name BossHealthBar

# --- CONFIGURAÇÕES DE JUICE ---
@export_group("Damage Feedback")
@export var damage_delay: float = 0.4
@export var damage_decay_duration: float = 0.45
@export var normal_tint: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var damage_bar_color: Color = Color(1.0, 0.85, 0.25, 1.0) # Amarelo-dourado vibrante

@export_group("Low Health Alert")
@export var low_health_threshold_ratio: float = 0.30
@export var low_health_color: Color = Color(1.3, 0.2, 0.2, 1.0) # Vermelho sangue enfurecido
@export var pulse_speed: float = 6.0

@export_group("Shake & Impact")
@export var max_shake_offset: float = 7.0
@export var shake_decay: float = 3.5
@export var enable_scale_punch: bool = true

# --- NÓS E VARIÁVEIS INTERNAS ---
@onready var damage_bar: TextureProgressBar = $DamageBar

var _base_position: Vector2
var _shake_trauma: float = 0.0
var _is_low_health: bool = false
var _pulse_time: float = 0.0

var _health_tween: Tween
var _damage_tween: Tween
var _flash_tween: Tween
var _scale_tween: Tween


func _ready() -> void:
	_base_position = position
	pivot_offset = size / 2.0
	
	_setup_damage_bar()
	call_deferred("_auto_connect_to_boss")


func _setup_damage_bar() -> void:
	if texture_over == null:
		texture_over = preload("res://assets/images/menu/health_border2.png")
	if texture_progress == null:
		texture_progress = preload("res://assets/images/menu/boss_health_progressr.png")
		
	# Se o nó DamageBar ainda não existir na cena, cria dinamicamente
	if not damage_bar:
		damage_bar = get_node_or_null("DamageBar")
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
			damage_bar.texture_under = texture_under if texture_under != null else preload("res://assets/images/menu/boss_health_under.png")
			damage_bar.texture_progress = texture_progress
			texture_under = null
			add_child(damage_bar)
			
	if damage_bar:
		damage_bar.tint_progress = damage_bar_color
		damage_bar.max_value = max_value
		damage_bar.value = value


func _auto_connect_to_boss() -> void:
	var boss = get_tree().get_first_node_in_group("boss")
	if not boss and owner:
		boss = owner.find_child("Boss*", true, false)
	if not boss:
		boss = get_node_or_null("../../StaticBody2D/BossAnsiedade")
		
	if boss and boss.has_signal("health_changed"):
		init_health(boss.current_health, boss.max_health)
		if not boss.health_changed.is_connected(set_health):
			boss.health_changed.connect(set_health)


func _process(delta: float) -> void:
	_handle_shake(delta)
	_handle_low_health_pulse(delta)


# Inicializa a barra do Boss com os valores máximos e atuais
func init_health(current: float, maximum: float) -> void:
	max_value = maximum
	value = current
	
	if damage_bar:
		damage_bar.max_value = maximum
		damage_bar.value = current
		
	_check_low_health(current)


# Atualiza a vida com todos os efeitos (shake, delay catch-up, flash, cor)
func set_health(new_health: float) -> void:
	var old_health = value
	var health_diff = new_health - old_health
	
	_check_low_health(new_health)
	
	# Se tomou dano
	if health_diff < 0:
		_on_damage_taken(new_health, abs(health_diff))
	# Se recuperou vida
	elif health_diff > 0:
		_on_heal(new_health)
	else:
		value = new_health
		if damage_bar:
			damage_bar.value = new_health


# Comportamento ao tomar dano
func _on_damage_taken(new_health: float, damage_amount: float) -> void:
	# 1. Animação rápida na barra principal para resposta ágil ao golpe
	if _health_tween and _health_tween.is_valid():
		_health_tween.kill()
		
	_health_tween = create_tween()
	_health_tween.tween_property(self, "value", new_health, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# 2. Barra de atraso (Damage Catch-Up Bar)
	if damage_bar:
		if _damage_tween and _damage_tween.is_valid():
			_damage_tween.kill()
			
		_damage_tween = create_tween()
		# Mantém a fatia amarela visível durante o delay
		_damage_tween.tween_interval(damage_delay)
		# Reduz suavemente até o novo valor
		_damage_tween.tween_property(damage_bar, "value", new_health, damage_decay_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
	# 3. Shake na barra
	var relative_damage = damage_amount / max(max_value, 1.0)
	var added_trauma = clampf(0.5 + relative_damage * 1.5, 0.6, 1.5)
	_add_shake(added_trauma)
	
	# 4. Scale Punch
	if enable_scale_punch:
		if _scale_tween and _scale_tween.is_valid():
			_scale_tween.kill()
		_scale_tween = create_tween()
		_scale_tween.tween_property(self, "scale", Vector2(1.02, 1.04), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_scale_tween.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	# 5. Flash branco de impacto
	_flash_impact()


# Comportamento em caso de cura
func _on_heal(new_health: float) -> void:
	if _health_tween and _health_tween.is_valid():
		_health_tween.kill()
	if _damage_tween and _damage_tween.is_valid():
		_damage_tween.kill()
		
	_health_tween = create_tween()
	_health_tween.tween_property(self, "value", new_health, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	if damage_bar:
		damage_bar.value = new_health


# Efeito de flash no impacto
func _flash_impact() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
		
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "tint_progress", Color(2.2, 2.2, 2.2, 1.0), 0.05)
	var target_c = low_health_color if _is_low_health else normal_tint
	_flash_tween.tween_property(self, "tint_progress", target_c, 0.1)


# Adiciona trauma de tremor
func _add_shake(amount: float) -> void:
	_shake_trauma = clampf(_shake_trauma + amount, 0.0, 1.5)


# Processa o tremor a cada frame
func _handle_shake(delta: float) -> void:
	if _shake_trauma > 0.0:
		_shake_trauma = maxf(_shake_trauma - delta * shake_decay, 0.0)
		var shake_power = _shake_trauma * _shake_trauma
		var offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * max_shake_offset * shake_power
		position = _base_position + offset
	else:
		if position != _base_position:
			position = _base_position


# Verifica se a vida está baixa e ajusta o estado
func _check_low_health(current: float) -> void:
	var ratio = current / max(max_value, 1.0)
	var was_low = _is_low_health
	_is_low_health = ratio <= low_health_threshold_ratio and current > 0
	
	if not _is_low_health and was_low:
		var color_tween = create_tween()
		color_tween.tween_property(self, "tint_progress", normal_tint, 0.3)
	elif current <= 0:
		tint_progress = Color(0.5, 0.1, 0.1, 1.0)


# Pulsação intensa quando o boss está em estado crítico / rage
func _handle_low_health_pulse(delta: float) -> void:
	if not _is_low_health:
		return
		
	if _flash_tween and _flash_tween.is_valid():
		return
		
	_pulse_time += delta * pulse_speed
	var pulse_factor = (sin(_pulse_time) + 1.0) * 0.5
	var pulse_color = low_health_color.lerp(Color(1.0, 0.4, 0.4, 1.0), pulse_factor * 0.35)
	tint_progress = pulse_color
