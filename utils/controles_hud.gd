class_name ControlesHud extends CanvasLayer

# Armazena quais arenas já exibiram o tutorial de controles durante a sessão
static var arenas_vistas: Dictionary = {}

@onready var panel: PanelContainer = $Panel

var duracao: float = 8.0
var _tween: Tween

static func mostrar_se_primeira_vez(parent: Node, id_arena: String, tempo_exibicao: float = 4.0) -> void:
	if arenas_vistas.get(id_arena, false):
		return
	arenas_vistas[id_arena] = true

	var cena = load("res://utils/controles_hud.tscn")
	if cena:
		var hud = cena.instantiate()
		hud.duracao = tempo_exibicao
		parent.add_child(hud)

static func resetar_historico() -> void:
	arenas_vistas.clear()

func _ready() -> void:
	if not panel:
		panel = get_node_or_null("Panel")

	if panel:
		panel.modulate.a = 0.0
		_tween = create_tween()
		_tween.tween_property(panel, "modulate:a", 1.0, 0.35)
		_tween.tween_interval(duracao)
		_tween.tween_property(panel, "modulate:a", 0.0, 0.6)
		_tween.tween_callback(queue_free)
