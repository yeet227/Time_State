extends MeshInstance

export var rotation_speed: Vector3 = Vector3(1.0, 0.0, 1.0)

func _physics_process(delta: float) -> void:
	rotate_x(rotation_speed.x * delta)
	rotate_z(rotation_speed.z * delta)
