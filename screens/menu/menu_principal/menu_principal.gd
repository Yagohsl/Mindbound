extends Control


# Botao jogar
func _on_btn_jogar_pressed():
	get_tree().change_scene_to_file("res://screens/cutscenes/cutscene_ansiedade/cutscene_caderno_ans.tscn")

# Botao sobre
func _on_btn_sobre_pressed():
	get_tree().change_scene_to_file("res://screens/menu/menu_principal/menu_sobre.tscn")

# Botao sair
func _on_btn_sair_pressed():
	get_tree().quit()
