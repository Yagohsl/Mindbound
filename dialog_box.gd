extends CanvasLayer

signal dialogo_finalizado

@onready var icone_retrato = $Panel/IconeRetrato
@onready var texto_label = $Panel/TextoLabel

var fila_dialogos: Array = []
var indice_atual: int = 0
var esta_digitando: bool = false

func _ready() -> void:
	visible = false

# Agora ela recebe um Array genérico de dicionários ou recursos
func iniciar_dialogo(dialogos: Array) -> void:
	fila_dialogos = dialogos
	indice_atual = 0
	visible = true
	get_tree().paused = true
	mostrar_proxima_fala()

func mostrar_proxima_fala() -> void:
	if indice_atual < fila_dialogos.size():
		var dados = fila_dialogos[indice_atual]
		# Suporta tanto formato de Array/Dicionário quanto Resource
		icone_retrato.texture = dados["icone"]
		texto_label.text = dados["texto"]
		
		texto_label.visible_characters = 0
		esta_digitando = true
		
		var qtd_caracteres = texto_label.text.length()
		var tempo_total = qtd_caracteres * 0.02
		
		var tween = create_tween()
		tween.tween_property(texto_label, "visible_characters", qtd_caracteres, tempo_total)
		await tween.finished
		esta_digitando = false
		
		indice_atual += 1
	else:
		fechar_dialogo()

func fechar_dialogo() -> void:
	visible = false
	get_tree().paused = false
	emit_signal("dialogo_finalizado")

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_accept"):
		if esta_digitando:
			var tween = get_tree().create_tween()
			texto_label.visible_characters = texto_label.text.length()
			esta_digitando = false
		else:
			mostrar_proxima_fala()
