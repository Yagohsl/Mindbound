extends Node2D


@onready var hero = $StaticBody2D/Heroi
@onready var hero_health_bar = $UI/HeroHealthBar

@onready var boss = $StaticBody2D/BossAnsiedade
@onready var boss_health_bar = $UI/BossHealthBar

@onready var dialog_box = $DialogBox

@export var player_node: CharacterBody2D
@export var boss_node: CharacterBody2D

var chefe_derrotado: bool = false

func _ready():
	
	dialog_box.iniciar_dialogo(boss.dialogos_inicio)
	if boss:
		boss.health_changed.connect(_on_boss_health_changed)
	if hero:
		hero.health_changed.connect(_on_hero_health_changed)
		
	dialog_box.dialogo_finalizado.connect(_on_dialogo_finalizado)
	
	# 3. Disparar o diálogo de Início de Batalha!
	if boss and boss.dialogos_inicio.size() > 0:
		dialog_box.call_deferred("iniciar_dialogo", boss.dialogos_inicio)		
	# inicializa barras com a vida máxima
	hero_health_bar.max_value = hero.max_health
	hero_health_bar.value = hero.current_health
	
	boss_health_bar.max_value = boss.max_health
	boss_health_bar.value = boss.current_health
	
	hero.health_changed.connect(update_hero_health)
	boss.health_changed.connect(update_boss_health)

# Quando o Boss tomar dano, checamos se ele morreu
func _on_boss_health_changed(new_health: int) -> void:
	if new_health <= 0 and not chefe_derrotado:
		chefe_derrotado = true

		# Desativa a física do boss imediatamente
		if boss:
			boss.set_physics_process(false) 
			
		# Faz a Arena esperar a animação de morte do Boss acabar
		if boss.anim.current_animation == "death" or boss.anim.is_playing():
			await get_tree().create_timer(3.0).timeout
		else:
			await get_tree().create_timer(3.0).timeout # Atraso extra de segurança
		# Só após a morte estar concluída na tela, a conversa começa e pausa o jogo
		dialog_box.iniciar_dialogo(boss.dialogos_vitoria)
		
		# Quando o Herói tomar dano, checamos se ele morreu
func _on_hero_health_changed(new_health: int) -> void:
	if hero.is_dead:
		# Inicia diálogo psicoeducativo de Derrota
		dialog_box.iniciar_dialogo(boss.dialogos_derrota)

# Função chamada automaticamente quando a caixa de texto se fecha
func _on_dialogo_finalizado() -> void:
	# Se a caixa fechou e o Boss estava com 0 de vida, encerra a fase
	if boss.is_dead:
		get_tree().change_scene_to_file("res://screens/menu/menu_principal/menu_principal.tscn")
	# Se a caixa fechou e o Player estava com 0 de vida, REINICIA O JOGO
	elif hero.current_health <= 0:
		get_tree().paused = false 
		get_tree().reload_current_scene() # Recarrega a cena da arena atual
	


# Função que será chamada quando o Herói tomar dano
func update_hero_health(new_health):
	var tween = create_tween()
	tween.tween_property(hero_health_bar, "value", new_health, 0.2)

# Função que será chamada quando o Boss tomar dano
func update_boss_health(new_health):
	var tween = create_tween()
	tween.tween_property(boss_health_bar, "value", new_health, 0.2)
