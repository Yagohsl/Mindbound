extends Control

@onready var anim_player = $AnimationPlayer

# Caminho correto para a arena de batalha do projeto
const ARENA_CENA = "res://screens/arenas/arena_depressao/arena_dep.tscn"

var pode_avancar: bool = false
var pulou_animacao: bool = false

func _ready() -> void:
	# Conecta o sinal para sabermos quando o texto terminou de ser escrito
	anim_player.animation_finished.connect(_on_animation_finished)

	# Inicia a animação de revelação da página e do texto
	anim_player.play("revelar_sintomas")

func _input(event: InputEvent) -> void:
	# Permite pular a cutscene pressionando Espaço, Enter ou o botão de Ataque
	if event.is_action_pressed("ui_accept"):
		if not pulou_animacao and anim_player.is_playing():
			# Se o jogador apertar enquanto digita, pula a animação e mostra todo o texto
			anim_player.seek(anim_player.get_animation("revelar_sintomas").length, true)
			pulou_animacao = true
			pode_avancar = true
		elif pode_avancar:
			# Se o texto já estiver todo na tela, o clique avança para a luta
			iniciar_batalha()

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "revelar_sintomas":
		pode_avancar = true

func iniciar_batalha() -> void:
	# Muda a cena para a Arena de Batalha para iniciar o combate contra a Ansiedade
	get_tree().change_scene_to_file(ARENA_CENA)
