extends CPUParticles2D

func _ready():
	# Garante que as faíscas começam a sair assim que a cena é criada
	emitting = true
	
	# Quando o tempo (Lifetime) acabar e a última faísca sumir, a cena apaga-se sozinha
	finished.connect(queue_free)
