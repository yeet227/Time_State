extends Spatial

const EnemyScene = preload("res://Scenes/Enemy_NPC.tscn")
const VehicleScene = preload("res://Scenes/Wasteland_Cruiser.tscn")
const PickupScript = preload("res://Scripts/Pickup.gd")
const ChestScript = preload("res://Scripts/Chest_Interactable.gd")

export var enable_day_night_cycle: bool = true
export var day_night_speed: float = 0.03

var _sun: DirectionalLight = null
var _landmark_zones := [
	{
		"id": "scrapper_garage",
		"name": "Scrapper Outpost & Garage",
		"faction": "Scrappers Coalition",
		"pos": Vector3(-120.0, 2.0, -40.0),
		"radius": 32.0
	},
	{
		"id": "imperial_citadel",
		"name": "The Imperial Citadel",
		"faction": "Ancient Dynasty",
		"pos": Vector3(-147.0, 6.0, 0.0),
		"radius": 48.0
	},
	{
		"id": "church_sanctuary",
		"name": "Sanctuary of the Church",
		"faction": "The Faithful Order",
		"pos": Vector3(-293.0, 6.0, 61.0),
		"radius": 42.0
	},
	{
		"id": "tank_graveyard",
		"name": "Tank Graveyard & Siren Outpost",
		"faction": "Iron Legion Remnants",
		"pos": Vector3(-434.0, 42.0, -31.0),
		"radius": 45.0
	},
	{
		"id": "jungle_basin",
		"name": "Overgrown Chrono Basin",
		"faction": "Untamed Wilds",
		"pos": Vector3(-646.0, -75.0, 10.0),
		"radius": 75.0
	}
]

func _ready() -> void:
	if has_node("DirectionalLight") and $DirectionalLight is DirectionalLight:
		_sun = $DirectionalLight

	_setup_existing_world_nodes()
	_spawn_world_pickups()
	_spawn_wasteland_vehicles()
	_spawn_world_enemies()
	_spawn_camp_chests()
	_spawn_landmark_trigger_areas()

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
			body.call("take_damage", 35.0, rock.global_transform.origin)

func _spawn_wasteland_vehicles() -> void:
	# 1. Starter Outpost Cruiser
	var cruiser1 := VehicleScene.instance() as Spatial
	cruiser1.name = "Wasteland_Cruiser_Starter"
	cruiser1.set("vehicle_id", "cruiser_outpost_1")
	cruiser1.set("vehicle_name", "Scrapper Interceptor")
	add_child(cruiser1)
	cruiser1.global_transform.origin = Vector3(-118.0, 2.2, -36.5)
	cruiser1.rotation_degrees.y = 45.0

	# 2. Tank Graveyard Cruiser
	var cruiser2 := VehicleScene.instance() as Spatial
	cruiser2.name = "Wasteland_Cruiser_Graveyard"
	cruiser2.set("vehicle_id", "cruiser_graveyard_2")
	cruiser2.set("vehicle_name", "Legion Raider Cruiser")
	add_child(cruiser2)
	cruiser2.global_transform.origin = Vector3(-415.0, 42.8, -26.0)
	cruiser2.rotation_degrees.y = -70.0

func _spawn_camp_chests() -> void:
	# Starter Camp Supply Chest
	_create_world_chest("starter_camp_chest", "Outpost Supply Locker", Vector3(-124.0, 1.2, -41.5), [
		{"id": "medkit", "name": "Nano Medkit", "count": 3, "type": "consumable", "value": 40.0, "description": "Restores 40 Health."},
		{"id": "ammo_pack", "name": "Energy Ammo Cell", "count": 4, "type": "ammo", "value": 20.0, "description": "Adds 20 Energy Rounds."},
		{"id": "sword_weapon", "name": "Wasteland Sword", "count": 1, "type": "weapon", "value": 38.0, "description": "Steel slashing blade for fast melee brawling."},
		{"id": "stamina_tonic", "name": "Stamina Tonic", "count": 2, "type": "consumable", "value": 60.0, "description": "Restores 60 Stamina immediately."}
	])

	# Imperial Citadel Vault Chest
	_create_world_chest("citadel_vault_chest", "Imperial Dynasty Vault", Vector3(-144.0, 5.5, 8.0), [
		{"id": "axe_prototype", "name": "Scrapper Battleaxe", "count": 1, "type": "weapon", "value": 72.0, "description": "Heavy crushing battleaxe. Massive cleave damage."},
		{"id": "time_crystal", "name": "Time Shard", "count": 2, "type": "artifact", "value": 0.25, "description": "Permanently increases Damage Multiplier by +0.25x."},
		{"id": "speed_core", "name": "Chrono Speed Core", "count": 2, "type": "artifact", "value": 0.25, "description": "Permanently increases Speed Multiplier by +0.25x."},
		{"id": "ammo_pack", "name": "Energy Ammo Cell", "count": 5, "type": "ammo", "value": 20.0, "description": "Adds 20 Energy Rounds."}
	])

	# Sanctuary Temple Altar
	_create_world_chest("church_altar_cache", "Sanctuary Relic Box", Vector3(-291.0, 6.2, 65.0), [
		{"id": "pillow_relic", "name": "Golden Pillow Relic", "count": 1, "type": "consumable", "value": 100.0, "description": "Fully restores Health and Stamina."},
		{"id": "medkit", "name": "Nano Medkit", "count": 4, "type": "consumable", "value": 40.0, "description": "Restores 40 Health."},
		{"id": "stamina_tonic", "name": "Stamina Tonic", "count": 3, "type": "consumable", "value": 60.0, "description": "Restores 60 Stamina immediately."}
	])

func _create_world_chest(chest_id: String, title: String, pos: Vector3, initial_items: Array) -> void:
	Global.ensure_chest_initialized(chest_id, initial_items)

	var chest_box := MeshInstance.new()
	chest_box.name = "Chest_%s" % chest_id
	var box_mesh := CubeMesh.new()
	box_mesh.size = Vector3(1.6, 1.1, 1.0)
	var mat := SpatialMaterial.new()
	mat.albedo_color = Color(0.55, 0.35, 0.12)
	mat.metallic = 0.4
	mat.roughness = 0.55
	box_mesh.material = mat
	chest_box.mesh = box_mesh

	var sb := StaticBody.new()
	var col := CollisionShape.new()
	var box_shape := BoxShape.new()
	box_shape.extents = Vector3(0.8, 0.55, 0.5)
	col.shape = box_shape
	sb.add_child(col)
	chest_box.add_child(sb)

	var interact := Spatial.new()
	interact.set_script(ChestScript)
	interact.chest_id = chest_id
	interact.chest_title = title
	chest_box.add_child(interact)

	add_child(chest_box)
	chest_box.global_transform.origin = pos

func _spawn_landmark_trigger_areas() -> void:
	for lm in _landmark_zones:
		var area := Area.new()
		area.name = "Trigger_%s" % lm["id"]
		var col := CollisionShape.new()
		var sphere := SphereShape.new()
		sphere.radius = lm["radius"]
		col.shape = sphere
		area.add_child(col)
		add_child(area)
		area.global_transform.origin = lm["pos"]
		var _err := area.connect("body_entered", self, "_on_landmark_body_entered", [lm])

func _on_landmark_body_entered(body: Node, lm: Dictionary) -> void:
	if body and (body.is_in_group("player") or body.name == "Player"):
		Global.discover_landmark(lm["id"], lm["name"], lm["faction"])

func _spawn_world_pickups() -> void:
	var pickup_Configs := [
		{"id": "main_pickup_1", "item": "medkit", "count": 1, "pos": Vector3(-116.5, 2.0, -44.0)},
		{"id": "main_pickup_2", "item": "ammo_pack", "count": 2, "pos": Vector3(-122.5, 2.0, -48.5)},
		{"id": "main_pickup_3", "item": "stamina_tonic", "count": 1, "pos": Vector3(-114.0, 2.0, -36.5)},
		{"id": "main_pickup_4", "item": "time_crystal", "count": 1, "pos": Vector3(-127.0, 2.0, -37.0)},
		{"id": "main_pickup_5", "item": "speed_core", "count": 1, "pos": Vector3(-108.0, 2.0, -29.0)},
		{"id": "citadel_pickup_1", "item": "time_crystal", "count": 1, "pos": Vector3(-150.0, 6.0, -12.0)},
		{"id": "citadel_pickup_2", "item": "ammo_pack", "count": 3, "pos": Vector3(-138.0, 6.0, 15.0)},
		{"id": "church_pickup_1", "item": "speed_core", "count": 1, "pos": Vector3(-298.0, 6.5, 54.0)},
		{"id": "graveyard_pickup_1", "item": "ammo_pack", "count": 4, "pos": Vector3(-428.0, 43.0, -35.0)}
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
		# Scrapper Outpost Perimeter (Raiders)
		{"id": "outpost_raider_1", "type": "raider", "pos": Vector3(-104.0, 4.0, -36.0)},
		{"id": "outpost_raider_2", "type": "raider", "pos": Vector3(-136.0, 4.0, -28.0)},
		{"id": "outpost_raider_3", "type": "raider", "pos": Vector3(-92.0, 4.0, -18.0)},

		# Imperial Citadel Guards (Drones + Heavy Automaton)
		{"id": "citadel_drone_1", "type": "drone", "pos": Vector3(-142.0, 8.0, -6.0)},
		{"id": "citadel_drone_2", "type": "drone", "pos": Vector3(-155.0, 8.0, 10.0)},
		{"id": "citadel_automaton_1", "type": "automaton", "pos": Vector3(-148.0, 5.0, 4.0)},

		# Church Foothills (Bouncing Gremlins)
		{"id": "church_gremlin_1", "type": "gremlin", "pos": Vector3(-284.0, 5.5, 50.0)},
		{"id": "church_gremlin_2", "type": "gremlin", "pos": Vector3(-302.0, 5.5, 68.0)},
		{"id": "church_gremlin_3", "type": "gremlin", "pos": Vector3(-275.0, 5.5, 74.0)},

		# Tank Graveyard Outpost (Heavy Automaton + Drones)
		{"id": "graveyard_automaton_1", "type": "automaton", "pos": Vector3(-430.0, 42.0, -25.0)},
		{"id": "graveyard_drone_1", "type": "drone", "pos": Vector3(-440.0, 46.0, -38.0)}
	]

	for esp in enemy_spawns:
		if Global.defeated_enemies.has(esp["id"]):
			continue
		var enemy := EnemyScene.instance()
		enemy.enemy_id = esp["id"]
		enemy.set("enemy_type", esp["type"])
		add_child(enemy)
		enemy.global_transform.origin = esp["pos"]
		enemy._home_position = esp["pos"]
