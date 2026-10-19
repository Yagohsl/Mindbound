extends Control
@onready var anim = $AnimationPlayer
@onready var texto = $VBoxContainer

# Nó da página esquerda (Imagem/Sprite do Boss)
@onready var boss_texture: TextureRect = $PaginaEsquerda/BossTexture

# Nós da página direita (Conteúdo Psicoeducativo)
@onready var nome_label: Label = $VBoxContainer/NomeLabel
@onready var subtitulo_label: Label = $VBoxContainer/SubtituloLabel
@onready var texto_psicoeducativo: RichTextLabel = $VBoxContainer/TextoPsicoeducativo

func _ready() -> void:
	if anim:
		anim.process_mode = Node.PROCESS_MODE_ALWAYS
		
	anim.play("abrir_caderno")
	await anim.animation_finished
	
	anim.play("mostrar_texto")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://screens/menu/menu_principal/menu_principal.tscn")
