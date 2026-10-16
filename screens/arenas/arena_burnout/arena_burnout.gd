extends Node2D

@onready var hero = $StaticBody2D/Heroi
@onready var hero_health_bar = $UI/HeroHealthBar

@onready var boss = $StaticBody2D/BossBurnout
@onready var boss_health_bar = $UI/BossHealthBar

@onready var dialog_box = $DialogBox

var chefe_derrotado: bool = false

func _ready():
	if boss:
		boss.player = hero
		boss.health_changed.connect(_on_boss_health_changed)
		boss.health_changed.connect(update_boss_health)
		boss_health_bar.max_value = boss.max_health
		boss_health_bar.value = boss.current_health
		
	if hero:
		hero.health_changed.connect(_on_hero_health_changed)
		hero.health_changed.connect(update_hero_health)
		hero_health_bar.init_health(hero.current_health, hero.max_health)
		
	if dialog_box:
		dialog_box.dialogo_finalizado.connect(_on_dialogo_finalizado)
		if boss and boss.dialogos_inicio.size() > 0:
			dialog_box.call_deferred("iniciar_dialogo", boss.dialogos_inicio)

func _on_boss_health_changed(new_health: int) -> void:
	if new_health <= 0 and not chefe_derrotado:
		chefe_derrotado = true
		if boss:
			boss.set_physics_process(false) 
			
		await get_tree().create_timer(2.5).timeout
		if dialog_box and boss:
			dialog_box.iniciar_dialogo(boss.dialogos_vitoria)

func _on_hero_health_changed(_new_health: int) -> void:
	if hero and hero.is_dead:
		pass

func _on_dialogo_finalizado() -> void:
	if boss and boss.is_dead:
		# Transição pós-vitória do Burnout
		pass
	elif hero and hero.current_health <= 0:
		get_tree().paused = false 
		get_tree().reload_current_scene()

func update_hero_health(new_health: int) -> void:
	hero_health_bar.set_health(new_health)

func update_boss_health(new_health: int) -> void:
	var tween = create_tween()
	tween.tween_property(boss_health_bar, "value", new_health, 0.2)
