extends Control


# Botao jogar
func _on_btn_jogar_pressed():
	get_tree().change_scene_to_file("res://screens/arena_batalha.tscn")

# Botao sobre
func _on_btn_sobre_pressed():
	get_tree().change_scene_to_file("res://screens/menu_sobre.tscn")

# Botao sair
func _on_btn_sair_pressed():
	get_tree().quit()
