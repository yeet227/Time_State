extends Spatial

const EnemyScene = preload("res://Scenes/Enemy_NPC.tscn")
const PickupScript = preload("res://Scripts/Pickup.gd")
const ChestScript = preload("res://Scripts/Chest_Interactable.gd")

export var enable_day_night_cycle: bool = true
export var day_night_speed: float = 0.03

var _sun: DirectionalLight = null

func _ready() -> void:
	if has_node("DirectionalLight") and $DirectionalLight is DirectionalLight:
		_sun = $DirectionalLight

	_setup_existing_world_nodes()
	_spawn_world_pickups()
	_spawn_world_enemies()
	_spawn_camp_chest()

func _process(delta: float) -> void:
	if enable_day_night_cycle and _sun and is_instance_valid(_sun):
		_sun.rotate_x(day_night_speed * delta)

func _setup_existing_world_nodes() -> void:
	# 1. Hook up the existing Chest node
	if has_node("Chest"):
		var chest_node := $Chest
		var chest_Marker := Spatial.new()
		chest_Marker.name = "MainChestInteractable"
		chest_Marker.set_script(ChestScript)
		chest_Marker.chest_id = "main_world_chest"
		chest_Marker.chest_title = "Ancient Supply Chest"
		chest_node.add_child(chest_Marker)

	# 2. Turn Pillow into a collectible Golden Pillow Relic pickup
	if has_node("Pillow"):
		var pillow_mesh: Spatial = $Pillow
		if Global.collected_world_items.has("world_pillow_relic"):
			pillow_mesh.queue_free()
		else:
			var p_area := Area.new()
			p_area.set_script(PickupScript)
			p_area.pickup_id = "world_pillow_relic"
			p_area.item_id = "pillow_relic"
			p_area.count = 1
			p_area.build_visual_if_empty = false
			add_child(p_area)
			p_area.global_transform.origin = pillow_mesh.global_transform.origin + Vector3(0.0, 0.5, 0.0)

	# 3. Connect Moveable_Rock_Damage to deal impact damage
	if has_node("Moveable_Rock_Damage") and $Moveable_Rock_Damage is RigidBody:
		var rock: RigidBody = $Moveable_Rock_Damage
		rock.contacts_reported = 4
		rock.contact_monitor = true
		if not rock.is_connected("body_entered", self, "_on_rock_body_entered"):
			var _err := rock.connect("body_entered", self, "_on_rock_body_entered", [rock])

func _on_rock_body_entered(body: Node, rock: RigidBody) -> void:
	if body and body.has_method("take_damage"):
		if rock.linear_velocity.length() > 1.5:
			body.call("take_damage", 25.0, rock.global_transform.origin)

func _spawn_camp_chest() -> void:
	# Spawn an accessible Supply Chest near the player's starting area
	var camp_chest := MeshInstance.new()
	camp_chest.name = "Camp_Supply_Chest"
	var box_mesh := CubeMesh.new()
	box_mesh.size = Vector3(1.6, 1.1, 1.0)
	var mat := SpatialMaterial.new()
	mat.albedo_color = Color(0.55, 0.35, 0.12)
	mat.metallic = 0.3
	mat.roughness = 0.6
	box_mesh.material = mat
	camp_chest.mesh = box_mesh

	var sb := StaticBody.new()
	var col := CollisionShape.new()
	var box_shape := BoxShape.new()
	box_shape.extents = Vector3(0.8, 0.55, 0.5)
	col.shape = box_shape
	sb.add_child(col)
	camp_chest.add_child(sb)

	var interact := Spatial.new()
	interact.set_script(ChestScript)
	interact.chest_id = "starter_camp_chest"
	interact.chest_title = "Outpost Storage Chest"
	camp_chest.add_child(interact)

	add_child(camp_chest)
	camp_chest.global_transform.origin = Vector3(-124.0, 1.2, -41.5)

func _spawn_world_pickups() -> void:
	var pickup_Configs := [
		{"id": "main_pickup_1", "item": "medkit", "count": 1, "pos": Vector3(-116.5, 2.0, -44.0)},
		{"id": "main_pickup_2", "item": "ammo_pack", "count": 2, "pos": Vector3(-122.5, 2.0, -48.5)},
		{"id": "main_pickup_3", "item": "stamina_tonic", "count": 1, "pos": Vector3(-114.0, 2.0, -36.5)},
		{"id": "main_pickup_4", "item": "time_crystal", "count": 1, "pos": Vector3(-127.0, 2.0, -37.0)},
		{"id": "main_pickup_5", "item": "speed_core", "count": 1, "pos": Vector3(-108.0, 2.0, -29.0)}
	]

	for cfg in pickup_Configs:
		if Global.collected_world_items.has(cfg["id"]):
			continue
		var p := Area.new()
		p.set_script(PickupScript)
		p.pickup_id = cfg["id"]
		p.item_id = cfg["item"]
		p.count = cfg["count"]
		add_child(p)
		p.global_transform.origin = cfg["pos"]

func _spawn_world_enemies() -> void:
	var enemy_spawns := [
		{"id": "world_enemy_1", "pos": Vector3(-104.0, 4.0, -36.0)},
		{"id": "world_enemy_2", "pos": Vector3(-136.0, 4.0, -28.0)},
		{"id": "world_enemy_3", "pos": Vector3(-92.0, 4.0, -18.0)},
		{"id": "world_enemy_4", "pos": Vector3(-75.0, 4.0, 32.0)}
	]

	for esp in enemy_spawns:
		if Global.defeated_enemies.has(esp["id"]):
			continue
		var enemy := EnemyScene.instance()
		enemy.enemy_id = esp["id"]
		add_child(enemy)
		enemy.global_transform.origin = esp["pos"]
		enemy._home_position = esp["pos"]
