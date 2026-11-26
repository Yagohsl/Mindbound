extends CanvasLayer

# --- REFERÊNCIAS DE NÓS (@onready) ---
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var vbox_container: VBoxContainer = $VBoxContainer

# --- VARIÁVEIS INTERNAS ---
var _is_transitioning: bool = false


# --- MÉTODOS NATIVOS ---
func _ready() -> void:
	visible = false
	if anim:
		anim.process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _is_transitioning:
			return

		var parent: Node = get_parent()
		if parent:
			var dialog_box: CanvasLayer = parent.get_node_or_null("DialogBox")
			var dialogo_box: CanvasLayer = parent.get_node_or_null("DialogoBox")

			if (dialog_box and dialog_box.visible) or (dialogo_box and dialogo_box.visible):
				return

		alternar_pausa()


# --- CONTROLE DE PAUSA ---
func alternar_pausa() -> void:
	if _is_transitioning:
		return

	_is_transitioning = true

	if not get_tree().paused:
		get_tree().paused = true
		visible = true

		if vbox_container:
			vbox_container.visible = true

		if anim and anim.has_animation("abrir_caderno"):
			anim.play("abrir_caderno")
			await anim.animation_finished

		if get_tree().paused and anim and anim.has_animation("mostrar_texto"):
			anim.play("mostrar_texto")
	else:
		if vbox_container:
			vbox_container.visible = false

		if anim and anim.has_animation("abrir_caderno"):
			anim.play_backwards("abrir_caderno")
			await anim.animation_finished

		visible = false
		get_tree().paused = false

	_is_transitioning = false


# --- CALLBACKS DE BOTÕES ---
func _on_botao_continuar_pressed() -> void:
	alternar_pausa()


func _on_botao_reiniciar_pressed() -> void:
	_is_transitioning = false
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_botao_menu_pressed() -> void:
	_is_transitioning = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://screens/menu/menu_principal/menu_principal.tscn")
