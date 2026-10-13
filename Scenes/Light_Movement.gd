extends DirectionalLight

export var speed: float = 125.0
export var target_point: Vector3 = Vector3(10, 10, 0)

func _process(delta: float) -> void:
	var current_pos: Vector3 = transform.origin
	var distance: float = current_pos.distance_to(target_point)
	
	if distance > 0.05:
		var direction: Vector3 = (target_point - current_pos).normalized()
		translation += direction * speed * delta
	else:
		translation = target_point
		set_process(false) # Destination reached, sleep process to optimize CPU
