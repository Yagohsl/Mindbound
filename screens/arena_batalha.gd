extends Node2D


@onready var hero = $Hero
@onready var hero_health_bar = $UI/HeroHealthBar

@onready var boss = $BossAnxiety
@onready var boss_health_bar = $UI/BossHealthBar

func _ready():
	# Inicializamos as barras com a vida máxima dos lutadores
	hero_health_bar.max_value = hero.max_health
	hero_health_bar.value = hero.current_health
	
	boss_health_bar.max_value = boss.max_health
	boss_health_bar.value = boss.current_health

# Função que será chamada quando o Herói tomar dano
func update_hero_health(new_health):
	# A Godot tem ferramentas legais como o "create_tween()" se você quiser
	# que a barra desça suavemente, mas de forma direta é assim:
	hero_health_bar.value = new_health

# Função que será chamada quando o Boss tomar dano
func update_boss_health(new_health):
	boss_health_bar.value = new_health
