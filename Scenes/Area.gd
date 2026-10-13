extends Area

export var launch_force: float = 50.0

func _on_Area_body_entered(body: Node) -> void:
	if "velocity" in body:
		body.velocity.y = max(body.velocity.y, 0.0) + launch_force
	elif "_velocity" in body:
		body._velocity.y = max(body._velocity.y, 0.0) + launch_force

func _on_Area_body_exited(_body: Node) -> void:
	pass
