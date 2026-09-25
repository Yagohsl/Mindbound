class_name BossBase extends CharacterBody2D

signal health_changed(new_health)

@export_group("Atributos Base")
@export var max_health: int = 100
@export var attack_value: int = 15
@export var speed: float = 150.0
@export var attack_cooldown: float = 2.0
@export var player: Node2D

@export_group("Knockback")
@export var boss_knockback_force: Vector2 = Vector2(250.0, -90.0)
@export var boss_knockback_duration: float = 0.15

@export_group("Diálogos e UI")
@export var player_icon: Texture2D
@export var boss_icon: Texture2D

var current_health: int
var is_dead: bool = false
var is_in_knockback: bool = false
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

var dialogos_inicio: Array[Dictionary] = []
var dialogos_vitoria: Array[Dictionary] = []
var dialogos_derrota: Array[Dictionary] = []

@onready var anim = $AnimationPlayer
@onready var sprite = $Sprite2D
@onready var decision_timer = $DecisionTimer
@onready var damage_area = $DamageArea
@onready var dialog_box = $DialogBox

func _ready() -> void:
	current_health = max_health
	_setup_dialogues()
	_custom_ready()

# --- SISTEMA DE DANO E DIFICULDADE ---
func take_damage(amount: int, attacker_pos: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return

	current_health = clampi(current_health - amount, 0, max_health)
	health_changed.emit(current_health)

	if attacker_pos != Vector2.ZERO and _can_receive_knockback():
		apply_knockback(attacker_pos)

	var life_percent: float = float(current_health) / float(max_health)
	_apply_dynamic_difficulty(life_percent)

	flash()
	if current_health <= 0:
		die()

func apply_knockback(attacker_pos: Vector2) -> void:
	is_in_knockback = true
	var dir_x: float = signf(global_position.x - attacker_pos.x)
	if dir_x == 0.0:
		dir_x = 1.0 if sprite.flip_h else -1.0

	velocity.x = dir_x * boss_knockback_force.x
	velocity.y = boss_knockback_force.y

	await get_tree().create_timer(boss_knockback_duration, false).timeout
	is_in_knockback = false

# --- EFEITOS E MORTE ---
func flash() -> void:
	if not sprite.material: return
	var mat = sprite.material
	var tween = create_tween()
	tween.tween_property(mat, "shader_parameter/flash_modifier", 1.0, 0.0)
	tween.tween_property(mat, "shader_parameter/flash_modifier", 0.0, 0.15)

func flip_sprite(dir: float) -> void:
	if dir != 0.0:
		sprite.flip_h = (dir < 0)

func die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	anim.play("death")
	_on_death()

# --- MÉTODOS VIRTUAIS (Sobrescritos nos scripts filhos) ---
func _setup_dialogues() -> void: pass
func _custom_ready() -> void: pass
func _apply_dynamic_difficulty(_life_percent: float) -> void: pass
func _can_receive_knockback() -> bool: return true
func _on_death() -> void: pass
