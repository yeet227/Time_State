extends Area

var direction: Vector3 = Vector3.FORWARD
var speed: float = 42.0
var damage: float = 25.0
var shooter: Node = null
var is_enemy_projectile: bool = false
var lifetime: float = 4.0

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1

	# Build collision shape
	var col := CollisionShape.new()
	var sphere_shape := SphereShape.new()
	sphere_shape.radius = 0.25
	col.shape = sphere_shape
	add_child(col)

	# Build glowing visual orb
	var mesh_inst := MeshInstance.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.18
	sphere_mesh.height = 0.36
	sphere_mesh.radial_segments = 12
	sphere_mesh.rings = 6

	var mat := SpatialMaterial.new()
	mat.flags_unshaded = true
	if is_enemy_projectile:
		mat.albedo_color = Color(1.0, 0.2, 0.15, 1.0)
	else:
		mat.albedo_color = Color(0.2, 0.85, 1.0, 1.0)
	sphere_mesh.material = mat
	mesh_inst.mesh = sphere_mesh
	add_child(mesh_inst)

	var _err := connect("body_entered", self, "_on_body_entered")

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return

	global_translate(direction * speed * delta)

func _on_body_entered(body: Node) -> void:
	if body == null or body == shooter:
		return

	if is_enemy_projectile:
		if body.is_in_group("enemy"):
			return
		if body.has_method("take_damage"):
			body.call("take_damage", damage, global_transform.origin)
			queue_free()
		elif body is StaticBody or body is GridMap:
			queue_free()
	else:
		if body.is_in_group("player"):
			return
		if body.has_method("take_damage"):
			body.call("take_damage", damage)
			queue_free()
		elif body is StaticBody or body is RigidBody:
			if body is RigidBody:
				body.apply_central_impulse(direction * 12.0)
			queue_free()
