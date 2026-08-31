extends CanvasLayer

func _ready() -> void:
	visible = false # Começa oculto

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): # A tecla ESC por padrão
		# Procura a caixa de diálogo na mesma cena (Arena)
		var dialog_box = get_parent().get_node_or_null("DialogBox")
		var dialogo_box = get_parent().get_node_or_null("DialogoBox")

		# Se a caixa de texto estiver aberta na tela, aborta o pause
		if (dialog_box and dialog_box.visible) or (dialogo_box and dialogo_box.visible):
			return 

		alternar_pausa()

func alternar_pausa() -> void:
	var esta_pausado = get_tree().paused
	get_tree().paused = not esta_pausado
	visible = not esta_pausado

func _on_botao_continuar_pressed() -> void:
	alternar_pausa()

func _on_botao_reiniciar_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_botao_menu_pressed() -> void:
	get_tree().paused = false
	# Mude o caminho abaixo para a cena correta do seu menu principal, se houver
	get_tree().change_scene_to_file("res://screens/menu_principal.tscn")
