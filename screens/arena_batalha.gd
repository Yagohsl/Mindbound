extends Node2D


@onready var hero = $StaticBody2D/Heroi
@onready var hero_health_bar = $UI/HeroHealthBar

@onready var boss = $StaticBody2D/BossAnsiedade
@onready var boss_health_bar = $UI/BossHealthBar

func _ready():
	# inicializa barras com a vida máxima
	hero_health_bar.max_value = hero.max_health
	hero_health_bar.value = hero.current_health
	
	boss_health_bar.max_value = boss.max_health
	boss_health_bar.value = boss.current_health
	
	hero.health_changed.connect(update_hero_health)
	boss.health_changed.connect(update_boss_health)

# Função que será chamada quando o Herói tomar dano
func update_hero_health(new_health):
	var tween = create_tween()
	tween.tween_property(hero_health_bar, "value", new_health, 0.2)

# Função que será chamada quando o Boss tomar dano
func update_boss_health(new_health):
	var tween = create_tween()
	tween.tween_property(boss_health_bar, "value", new_health, 0.2)
