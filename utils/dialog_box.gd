extends CanvasLayer

signal dialogo_finalizado

@onready var icone_retrato = $Panel/IconeRetrato
@onready var texto_label = $Panel/TextoLabel

var fila_dialogos: Array = []
var indice_atual: int = 0
var esta_digitando: bool = false
var pode_avancar: bool = false
var tween_atual: Tween # Variável para controlar a animação e impedir fantasmas

func _ready() -> void:
	visible = false

func iniciar_dialogo(dialogos: Array) -> void:
	fila_dialogos = dialogos
	indice_atual = 0
	visible = true
	get_tree().paused = true 

	pode_avancar = false
	mostrar_proxima_fala()

	# O 'true' garante que o timer não congele junto com o jogo
	await get_tree().create_timer(0.3, true).timeout
	pode_avancar = true

func mostrar_proxima_fala() -> void:
	if indice_atual < fila_dialogos.size():
		var dados = fila_dialogos[indice_atual]
		icone_retrato.texture = dados["icone"]
		texto_label.text = dados["texto"]
		texto_label.visible_characters = 0

		esta_digitando = true

		var qtd_caracteres = texto_label.text.length()
		var tempo_total = qtd_caracteres * 0.02

		# Cria a animação e armazena na variável para termos controle absoluto sobre ela
		tween_atual = get_tree().create_tween().bind_node(self).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween_atual.tween_property(texto_label, "visible_characters", qtd_caracteres, tempo_total)

		await tween_atual.finished
		esta_digitando = false
	else:
		fechar_dialogo()

func fechar_dialogo() -> void:
	visible = false
	get_tree().paused = false
	dialogo_finalizado.emit()

func _input(event: InputEvent) -> void:
	# Usamos is_action_pressed normal, mas com o fluxo de controle limpo
	if visible and pode_avancar and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()

		if esta_digitando:
		# Se o jogador pular o texto, MATAMOS a animação antiga para ela não bugar o índice
			if tween_atual and tween_atual.is_running():
				tween_atual.kill()

			texto_label.visible_characters = texto_label.text.length()
			esta_digitando = false
		else:
			# O índice agora SÓ soma quando o jogador realmente pede a próxima fala
			indice_atual += 1
			mostrar_proxima_fala()
