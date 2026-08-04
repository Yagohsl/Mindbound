extends CanvasLayer

func _ready() -> void:
	visible = false # Começa oculto

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): # A tecla ESC por padrão
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
