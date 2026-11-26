extends Node2D

# --- CONFIGURAÇÕES EXPORTADAS ---
@export var player_node: CharacterBody2D
@export var boss_node: CharacterBody2D

# --- REFERÊNCIAS DE NÓS (@onready) ---
@onready var hero: CharacterBody2D = $StaticBody2D/Heroi
@onready var hero_health_bar: HeroHealthBar = $UI/HeroHealthBar
@onready var boss: BossBase = $StaticBody2D/BossAnsiedade
@onready var boss_health_bar: BossHealthBar = $UI/BossHealthBar
@onready var dialog_box: CanvasLayer = $DialogBox

# --- VARIÁVEIS DE ESTADO ---
var chefe_derrotado: bool = false


# --- MÉTODOS NATIVOS ---
func _ready() -> void:
	if boss:
		boss.health_changed.connect(_on_boss_health_changed)
		if boss_health_bar:
			boss_health_bar.init_health(float(boss.current_health), float(boss.max_health))
	if hero:
		hero.health_changed.connect(_on_hero_health_changed)
		if hero_health_bar:
			hero_health_bar.init_health(float(hero.current_health), float(hero.max_health))

	if dialog_box and dialog_box.has_signal("dialogo_finalizado"):
		dialog_box.dialogo_finalizado.connect(_on_dialogo_finalizado)

	if boss and boss.dialogos_inicio.size() > 0:
		dialog_box.call_deferred("iniciar_dialogo", boss.dialogos_inicio)
	else:
		ControlesHud.mostrar_se_primeira_vez(self, "ansiedade")


# --- COMBATE & TRANSIÇÕES ---
func _on_boss_health_changed(new_health: int) -> void:
	if new_health <= 0 and not chefe_derrotado:
		chefe_derrotado = true

		if boss and boss.anim and (boss.anim.current_animation == "death" or boss.anim.is_playing()):
			await get_tree().create_timer(3.0).timeout
		else:
			await get_tree().create_timer(3.0).timeout

		if dialog_box and boss:
			dialog_box.iniciar_dialogo(boss.dialogos_vitoria)


func _on_hero_health_changed(_new_health: int) -> void:
	if hero and hero.is_dead:
		pass


func _on_dialogo_finalizado() -> void:
	if boss and boss.is_dead:
		get_tree().change_scene_to_file("res://screens/cutscenes/cutscene_ansiedade/cutscene_vitoria_caderno_ans.tscn")
	elif hero and hero.current_health <= 0:
		get_tree().paused = false
		get_tree().reload_current_scene()
	else:
		ControlesHud.mostrar_se_primeira_vez(self, "ansiedade")


func update_hero_health(new_health: int) -> void:
	if hero_health_bar:
		hero_health_bar.set_health(float(new_health))


func update_boss_health(new_health: int) -> void:
	if boss_health_bar:
		boss_health_bar.set_health(float(new_health))
