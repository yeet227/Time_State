extends KinematicBody

export var move_speed: float = 6.0
export var gravity: float = 20.0
export var stop_distance: float = 1.5

var velocity: Vector3 = Vector3.ZERO
var target_node: Spatial = null

func set_target(new_target: Spatial) -> void:
	target_node = new_target

func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.1

	if target_node and is_instance_valid(target_node):
		var current_pos := global_transform.origin
		var target_pos := target_node.global_transform.origin
		var diff := target_pos - current_pos
		diff.y = 0.0 # Restrict horizontal calculation

		var distance := diff.length()
		if distance > stop_distance:
			var dir := diff.normalized()
			velocity.x = dir.x * move_speed
			velocity.z = dir.z * move_speed

			# Rotate enemy to face target smoothly
			var target_angle := atan2(-dir.x, -dir.z)
			rotation.y = lerp_angle(rotation.y, target_angle, 8.0 * delta)
		else:
			velocity.x = lerp(velocity.x, 0.0, 10.0 * delta)
			velocity.z = lerp(velocity.z, 0.0, 10.0 * delta)
	else:
		velocity.x = lerp(velocity.x, 0.0, 10.0 * delta)
		velocity.z = lerp(velocity.z, 0.0, 10.0 * delta)

	velocity = move_and_slide(velocity, Vector3.UP)