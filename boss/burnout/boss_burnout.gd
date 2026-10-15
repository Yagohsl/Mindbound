extends BossBase

enum State {
	IDLE,
	RUN,
	DEATH
}



func _setup_dialogues() -> void:
	dialogos_inicio = [
		{"icone": player_icon, "texto": "Tantas ideias e impulsos ao mesmo tempo... Preciso manter a calma e focar no que importa!"},
		{"icone": boss_icon, "texto": "Olhe para lá! E para cá! Tantos estímulos... você nunca vai conseguir escolher um só!"},
		{"icone": player_icon, "texto": "Não vou me perder no caos. Eu decido para onde vai a minha atenção!"}
	]
	
	dialogos_vitoria = [
		{"icone": player_icon, "texto": "Consegui filtrar o ruído e focar no essencial."},
		{"icone": boss_icon, "texto": "A mente ainda corre a mil por hora..."},
		{"icone": player_icon, "texto": "E tá tudo bem ser acelerado, o segredo é direcionar essa energia sem me afogar nas distrações."}
	]
	
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	move_and_slide()
