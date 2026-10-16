extends CanvasLayer
@onready var anim = $AnimationPlayer

func _ready() -> void:
	visible = false
	if anim:
		anim.process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Procura a caixa de diálogo na mesma cena
		var dialog_box = get_parent().get_node_or_null("DialogBox")
		var dialogo_box = get_parent().get_node_or_null("DialogoBox")

		# Se a caixa de texto estiver aberta na tela, aborta o pause
		if (dialog_box and dialog_box.visible) or (dialogo_box and dialogo_box.visible):
			return 

		alternar_pausa()

func alternar_pausa() -> void:
	if not get_tree().paused:
		# --- ABRIR O MENU ---
		get_tree().paused = true
		visible = true
		
		# Restaura os elementos de texto/interface
		$VBoxContainer.visible = true 
		
		anim.play("abrir_caderno")
		await anim.animation_finished
		
		if get_tree().paused:
			anim.play("mostrar_texto")
	else:
		# --- FECHAR O MENU ---
		$VBoxContainer.visible = false 
		
		#Toca a animação invertida MANTENDO O JOGO PAUSADO
		anim.play_backwards("abrir_caderno")
		await anim.animation_finished
		
		#Só esconde a interface e despausa a física/jogo no final da animação
		visible = false
		get_tree().paused = false
		
func _on_botao_continuar_pressed() -> void:
	alternar_pausa()

func _on_botao_reiniciar_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_botao_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://screens/menu/menu_principal/menu_principal.tscn")
