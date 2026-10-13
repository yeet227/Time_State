extends Area

export var pickup_id: String = ""
export var item_id: String = "medkit"
export var count: int = 1
export var build_visual_if_empty: bool = true

var _base_y: float = 0.0
var _time: float = 0.0

func _ready() -> void:
	if not pickup_id.empty() and Global.collected_world_items.has(pickup_id):
		queue_free()
		return

	add_to_group("pickup")
	_base_y = translation.y

	var has_col := false
	var has_mesh := false
	for child in get_children():
		if child is CollisionShape:
			has_col = true
		elif child is MeshInstance:
			has_mesh = true

	if not has_col:
		var col := CollisionShape.new()
		var shape := SphereShape.new()
		shape.radius = 1.1
		col.shape = shape
		add_child(col)

	if build_visual_if_empty and not has_mesh:
		var mesh_inst := MeshInstance.new()
		mesh_inst.name = "VisualMesh"
		var mesh := CubeMesh.new()
		mesh.size = Vector3(0.55, 0.55, 0.55)
		var mat := SpatialMaterial.new()
		mat.albedo_color = _get_item_color(item_id)
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy = 0.6
		mesh.material = mat
		mesh_inst.mesh = mesh
		add_child(mesh_inst)

	if not is_connected("body_entered", self, "_on_body_entered"):
		var _err := connect("body_entered", self, "_on_body_entered")

func _get_item_color(id: String) -> Color:
	match id:
		"medkit":
			return Color(0.2, 0.9, 0.35)
		"stamina_tonic":
			return Color(0.95, 0.85, 0.2)
		"ammo_pack":
			return Color(0.2, 0.75, 1.0)
		"time_crystal":
			return Color(0.85, 0.25, 1.0)
		"speed_core":
			return Color(1.0, 0.5, 0.15)
		_:
			return Color(0.9, 0.9, 0.9)

func _physics_process(delta: float) -> void:
	_time += delta * 2.5
	translation.y = _base_y + sin(_time) * 0.18
	rotate_y(1.6 * delta)

func _on_body_entered(body: Node) -> void:
	if body and (body.is_in_group("player") or body.name == "Player"):
		collect(body)

func collect(_player: Node = null) -> void:
	if not pickup_id.empty():
		Global.collected_world_items[pickup_id] = true
	Global.add_item(item_id, count)
	queue_free()
