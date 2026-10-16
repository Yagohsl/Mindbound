extends TextureProgressBar
class_name HeroHealthBar

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
	
	_setup_textures_and_damage_bar()
	call_deferred("_auto_connect_to_hero")


func _setup_textures_and_damage_bar() -> void:
	# Garante texturas visuais padronizadas se não estiverem definidas
	if texture_over == null:
		texture_over = preload("res://assets/images/menu/health_border..png")
	if texture_progress == null:
		texture_progress = preload("res://assets/images/menu/health_progress.png")
		
	# Se a barra de dano fantasma ainda não foi criada na cena, cria em runtime
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
			damage_bar.texture_under = texture_under if texture_under != null else preload("res://assets/images/menu/health_under.png")
			damage_bar.texture_progress = texture_progress
			texture_under = null
			add_child(damage_bar)
			
	if damage_bar:
		damage_bar.tint_progress = damage_bar_color
		damage_bar.max_value = max_value
		damage_bar.value = value


func _auto_connect_to_hero() -> void:
	var hero = get_tree().get_first_node_in_group("player")
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


# Inicializa a barra com os valores iniciais de vida
func init_health(current: float, maximum: float) -> void:
	max_value = maximum
	value = current
	
	if damage_bar:
		damage_bar.max_value = maximum
		damage_bar.value = current
		
	_check_low_health(current)


# Atualiza a vida com todos os efeitos suculentos (shake, delay, cor, etc.)
func set_health(new_health: float) -> void:
	var old_health = value
	var health_diff = new_health - old_health
	
	_check_low_health(new_health)
	
	# Se tomou dano
	if health_diff < 0:
		_on_damage_taken(new_health, abs(health_diff))
	# Se recuperou vida (cura)
	elif health_diff > 0:
		_on_heal(new_health)
	else:
		value = new_health
		if damage_bar:
			damage_bar.value = new_health


# Comportamento quando toma dano
func _on_damage_taken(new_health: float, damage_amount: float) -> void:
	# 1. Animação rápida na barra principal para feedback ágil
	if _health_tween and _health_tween.is_valid():
		_health_tween.kill()
		
	_health_tween = create_tween()
	_health_tween.tween_property(self, "value", new_health, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# 2. Barra de atraso (Damage Catch-Up Bar)
	if damage_bar:
		if _damage_tween and _damage_tween.is_valid():
			_damage_tween.kill()
			
		_damage_tween = create_tween()
		# Aguarda o delay para mostrar o pedaço perdido
		_damage_tween.tween_interval(damage_delay)
		# Reduz suavemente até a nova vida
		_damage_tween.tween_property(damage_bar, "value", new_health, damage_decay_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
	# 3. Shake na barra
	# O trauma é proporcional ao dano, com mínimo de 0.6 para hits leves e teto de 1.5
	var relative_damage = damage_amount / max(max_value, 1.0)
	var added_trauma = clampf(0.5 + relative_damage * 1.5, 0.6, 1.5)
	_add_shake(added_trauma)
	
	# 4. Scale Punch (pequena batida de expansão no impacto)
	if enable_scale_punch:
		if _scale_tween and _scale_tween.is_valid():
			_scale_tween.kill()
		_scale_tween = create_tween()
		_scale_tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_scale_tween.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	# 5. Flash rápido de impacto
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


# Efeito de Flash branco no momento do dano
func _flash_impact() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
		
	_flash_tween = create_tween()
	# Brilho momentâneo
	_flash_tween.tween_property(self, "tint_progress", Color(2.0, 2.0, 2.0, 1.0), 0.05)
	# Retorna para a cor adequada (normal ou avermelhada)
	var target_c = low_health_color if _is_low_health else normal_color
	_flash_tween.tween_property(self, "tint_progress", target_c, 0.1)


# Adiciona trauma de tremor
func _add_shake(amount: float) -> void:
	_shake_trauma = clampf(_shake_trauma + amount, 0.0, 1.5)


# Atualiza o tremor a cada frame
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
		# Transição suave de volta ao normal caso tenha saído da vida baixa
		var color_tween = create_tween()
		color_tween.tween_property(self, "tint_progress", normal_color, 0.3)
	elif current <= 0:
		tint_progress = low_health_color


# Pulsação da cor quando a vida está baixa
func _handle_low_health_pulse(delta: float) -> void:
	if not _is_low_health:
		return
		
	# Não interfere se estiver durante o micro flash de dano
	if _flash_tween and _flash_tween.is_valid():
		return
		
	_pulse_time += delta * pulse_speed
	# Oscila suavemente entre 0.0 e 1.0 usando seno
	var pulse_factor = (sin(_pulse_time) + 1.0) * 0.5
	
	# Interpola entre vermelho intenso e vermelho mais claro/vivo
	var pulse_color = low_health_color.lerp(Color(1.0, 0.65, 0.65, 1.0), pulse_factor * 0.4)
	tint_progress = pulse_color
