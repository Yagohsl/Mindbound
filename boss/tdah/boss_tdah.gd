extends BossBase


enum State {
	IDLE,
	RUN,
	THOUGHTS,
	TELEPORT,
	EXPLOSION_PREP,
	EXPLOSION,
	DASH_PREP,
	DASH,
	DEATH
}

#signal health_changed(new_health: int)

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	
	move_and_slide()
