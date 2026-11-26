extends Control

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D
@onready var texto: RichTextLabel = get_node_or_null("Texto")
@onready var texto2: RichTextLabel = get_node_or_null("Texto2")

# Caminho correto para a arena de batalha do projeto
const ARENA_CENA = "res://screens/arenas/arena_tdah/arena_tdah.tscn"

var pode_avancar: bool = false
var pulou_animacao: bool = false

func _ready() -> void:
	anim_player.animation_finished.connect(_on_animation_finished)
	anim_player.play("abrir_caderno")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		if pode_avancar:
			iniciar_batalha()
		else:
			pular_para_texto_completo()

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "abrir_caderno":
		if not pulou_animacao:
			anim_player.play("revelar_sintomas")
	elif anim_name == "revelar_sintomas":
		pode_avancar = true

func pular_para_texto_completo() -> void:
	pulou_animacao = true
	anim_player.stop()

	if sprite:
		sprite.frame = 3

	if texto:
		texto.visible_ratio = 1.0
	if texto2:
		texto2.visible_ratio = 1.0

	await get_tree().create_timer(0.2).timeout
	pode_avancar = true

func iniciar_batalha() -> void:
	get_tree().change_scene_to_file(ARENA_CENA)
