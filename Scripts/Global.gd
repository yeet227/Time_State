extends Node

signal stats_changed
signal inventory_changed
signal chest_changed(chest_id)
signal cheats_changed
signal settings_changed
signal notification_requested(message)

const SAVE_FILE_PATH := "user://time_state_save.json"
const SETTINGS_FILE_PATH := "user://time_state_settings.cfg"

# --- Settings ---
var ShowFPS: bool = true
var stamina: bool = true
var mouse_sensitivity: float = 0.10
var fov: float = 85.0
var vsync_enabled: bool = false
var fullscreen_enabled: bool = false
var master_volume: float = 0.85

# --- Cheat Flags & Multipliers ---
var god_mode: bool = false
var infinite_speed: bool = false
var flight_enabled: bool = false
var speed_multiplier: float = 1.0
var flight_multiplier: float = 1.0
var jump_multiplier: float = 1.0
var damage_multiplier: float = 1.0

# --- Player Persistent Stats ---
var max_health: float = 100.0
var health: float = 100.0
var max_stamina: float = 100.0
var current_stamina: float = 100.0
var ammo: int = 30
var max_ammo: int = 150

# --- Item Database ---
const ITEM_DB := {
	"medkit": {
		"id": "medkit",
		"name": "Nano Medkit",
		"type": "consumable",
		"value": 40.0,
		"description": "Restores 40 Health."
	},
	"stamina_tonic": {
		"id": "stamina_tonic",
		"name": "Stamina Tonic",
		"type": "consumable",
		"value": 60.0,
		"description": "Restores 60 Stamina immediately."
	},
	"ammo_pack": {
		"id": "ammo_pack",
		"name": "Energy Ammo Cell",
		"type": "ammo",
		"value": 20.0,
		"description": "Adds 20 Energy Rounds."
	},
	"time_crystal": {
		"id": "time_crystal",
		"name": "Time Shard",
		"type": "artifact",
		"value": 0.25,
		"description": "Permanently increases Damage Multiplier by +0.25x when used."
	},
	"speed_core": {
		"id": "speed_core",
		"name": "Chrono Speed Core",
		"type": "artifact",
		"value": 0.25,
		"description": "Permanently increases Speed Multiplier by +0.25x when used."
	},
	"pillow_relic": {
		"id": "pillow_relic",
		"name": "Golden Pillow Relic",
		"type": "consumable",
		"value": 100.0,
		"description": "Fully restores Health and Stamina."
	}
}

# --- Inventory & Chest Storage ---
var inventory: Array = []
var chest_storages: Dictionary = {}
var collected_world_items: Dictionary = {}
var defeated_enemies: Dictionary = {}
var pending_load_data: Dictionary = {}

func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	_init_default_inventory()
	load_settings()
	apply_settings()

func _init_default_inventory() -> void:
	inventory = [
		{"id": "medkit", "name": "Nano Medkit", "count": 2, "type": "consumable", "value": 40.0, "description": "Restores 40 Health."},
		{"id": "ammo_pack", "name": "Energy Ammo Cell", "count": 1, "type": "ammo", "value": 20.0, "description": "Adds 20 Energy Rounds."}
	]

func notify(message: String) -> void:
	emit_signal("notification_requested", message)

# --- Inventory Operations ---
func add_item(item_id: String, count: int = 1) -> void:
	if count <= 0 or not ITEM_DB.has(item_id):
		return
	for entry in inventory:
		if entry["id"] == item_id:
			entry["count"] += count
			emit_signal("inventory_changed")
			notify("Picked up %s (x%d)" % [entry["name"], count])
			return
	var template: Dictionary = ITEM_DB[item_id].duplicate()
	template["count"] = count
	inventory.append(template)
	emit_signal("inventory_changed")
	notify("Picked up %s (x%d)" % [template["name"], count])

func remove_item_at(index: int, count: int = 1) -> Dictionary:
	if index < 0 or index >= inventory.size():
		return {}
	var entry: Dictionary = inventory[index]
	var removed_count: int = int(min(count, entry["count"]))
	var result: Dictionary = entry.duplicate()
	result["count"] = removed_count
	entry["count"] -= removed_count
	if entry["count"] <= 0:
		inventory.remove(index)
	emit_signal("inventory_changed")
	return result

func use_item_at(index: int, player_node: Node = null) -> bool:
	if index < 0 or index >= inventory.size():
		return false
	var entry: Dictionary = inventory[index]
	var item_id: String = entry["id"]
	var used := false

	match item_id:
		"medkit":
			if health < max_health:
				health = min(max_health, health + float(entry["value"]))
				if player_node and "health" in player_node:
					player_node.health = health
				used = true
				notify("Used Nano Medkit (+40 HP)")
			else:
				notify("Health is already full!")
		"stamina_tonic":
			current_stamina = min(max_stamina, current_stamina + float(entry["value"]))
			if player_node and "current_stamina" in player_node:
				player_node.current_stamina = current_stamina
			used = true
			notify("Used Stamina Tonic (+60 STM)")
		"ammo_pack":
			if ammo < max_ammo:
				ammo = int(min(max_ammo, ammo + int(entry["value"])))
				used = true
				notify("Loaded +20 Energy Rounds")
			else:
				notify("Ammo is already full!")
		"time_crystal":
			damage_multiplier += float(entry["value"])
			used = true
			emit_signal("cheats_changed")
			notify("Time Shard absorbed! Damage Multiplier: %.2fx" % damage_multiplier)
		"speed_core":
			speed_multiplier += float(entry["value"])
			used = true
			emit_signal("cheats_changed")
			notify("Speed Core absorbed! Speed Multiplier: %.2fx" % speed_multiplier)
		"pillow_relic":
			health = max_health
			current_stamina = max_stamina
			if player_node:
				if "health" in player_node:
					player_node.health = health
				if "current_stamina" in player_node:
					player_node.current_stamina = current_stamina
			used = true
			notify("Golden Pillow Relic used! Full HP & Stamina restored!")

	if used:
		var _removed := remove_item_at(index, 1)
		emit_signal("stats_changed")
	return used

# --- Chest Storage Operations ---
func ensure_chest_initialized(chest_id: String, default_items: Array = []) -> void:
	if not chest_storages.has(chest_id):
		if default_items.empty():
			chest_storages[chest_id] = [
				{"id": "medkit", "name": "Nano Medkit", "count": 2, "type": "consumable", "value": 40.0, "description": "Restores 40 Health."},
				{"id": "ammo_pack", "name": "Energy Ammo Cell", "count": 3, "type": "ammo", "value": 20.0, "description": "Adds 20 Energy Rounds."},
				{"id": "time_crystal", "name": "Time Shard", "count": 1, "type": "artifact", "value": 0.25, "description": "Permanently increases Damage Multiplier by +0.25x when used."},
				{"id": "stamina_tonic", "name": "Stamina Tonic", "count": 2, "type": "consumable", "value": 60.0, "description": "Restores 60 Stamina immediately."}
			]
		else:
			chest_storages[chest_id] = default_items.duplicate(true)

func get_chest_items(chest_id: String) -> Array:
	ensure_chest_initialized(chest_id)
	return chest_storages[chest_id]

func transfer_to_chest(chest_id: String, inventory_index: int, count: int = 1) -> void:
	ensure_chest_initialized(chest_id)
	var item_data := remove_item_at(inventory_index, count)
	if item_data.empty():
		return
	var chest_list: Array = chest_storages[chest_id]
	for entry in chest_list:
		if entry["id"] == item_data["id"]:
			entry["count"] += item_data["count"]
			emit_signal("chest_changed", chest_id)
			return
	chest_list.append(item_data)
	emit_signal("chest_changed", chest_id)

func transfer_from_chest(chest_id: String, chest_index: int, count: int = 1) -> void:
	ensure_chest_initialized(chest_id)
	var chest_list: Array = chest_storages[chest_id]
	if chest_index < 0 or chest_index >= chest_list.size():
		return
	var entry: Dictionary = chest_list[chest_index]
	var move_count: int = int(min(count, entry["count"]))
	var item_id: String = entry["id"]
	entry["count"] -= move_count
	if entry["count"] <= 0:
		chest_list.remove(chest_index)
	add_item(item_id, move_count)
	emit_signal("chest_changed", chest_id)

func take_all_from_chest(chest_id: String) -> void:
	ensure_chest_initialized(chest_id)
	var chest_list: Array = chest_storages[chest_id]
	while not chest_list.empty():
		var entry: Dictionary = chest_list.pop_back()
		add_item(entry["id"], int(entry["count"]))
	emit_signal("chest_changed", chest_id)

# --- Settings System ---
func apply_settings() -> void:
	OS.vsync_enabled = vsync_enabled
	if OS.window_fullscreen != fullscreen_enabled:
		OS.window_fullscreen = fullscreen_enabled
	var bus_idx := AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		if master_volume <= 0.01:
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			AudioServer.set_bus_mute(bus_idx, false)
			AudioServer.set_bus_volume_db(bus_idx, linear2db(master_volume))
	emit_signal("settings_changed")

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "show_fps", ShowFPS)
	cfg.set_value("display", "fov", fov)
	cfg.set_value("display", "vsync", vsync_enabled)
	cfg.set_value("display", "fullscreen", fullscreen_enabled)
	cfg.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("audio", "master_volume", master_volume)
	var _err := cfg.save(SETTINGS_FILE_PATH)
	apply_settings()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_FILE_PATH) != OK:
		return
	ShowFPS = bool(cfg.get_value("display", "show_fps", ShowFPS))
	fov = float(cfg.get_value("display", "fov", fov))
	vsync_enabled = bool(cfg.get_value("display", "vsync", vsync_enabled))
	fullscreen_enabled = bool(cfg.get_value("display", "fullscreen", fullscreen_enabled))
	mouse_sensitivity = float(cfg.get_value("input", "mouse_sensitivity", mouse_sensitivity))
	master_volume = float(cfg.get_value("audio", "master_volume", master_volume))

# --- Save & Load System ---
func save_game(player_node: Spatial = null) -> bool:
	if player_node == null:
		var players := get_tree().get_nodes_in_group("player")
		if not players.empty():
			player_node = players[0] as Spatial

	var current_scene_path := ""
	if get_tree().current_scene:
		current_scene_path = get_tree().current_scene.filename

	var player_pos := Vector3.ZERO
	var player_rot_y := 0.0
	if player_node and is_instance_valid(player_node):
		player_pos = player_node.global_transform.origin
		player_rot_y = player_node.rotation.y
		if "health" in player_node:
			health = player_node.health
		if "current_stamina" in player_node:
			current_stamina = player_node.current_stamina

	var save_dict := {
		"scene": current_scene_path,
		"player": {
			"x": player_pos.x,
			"y": player_pos.y,
			"z": player_pos.z,
			"rot_y": player_rot_y,
			"health": health,
			"max_health": max_health,
			"stamina": current_stamina,
			"max_stamina": max_stamina,
			"ammo": ammo
		},
		"cheats": {
			"god_mode": god_mode,
			"infinite_speed": infinite_speed,
			"flight_enabled": flight_enabled,
			"speed_multiplier": speed_multiplier,
			"flight_multiplier": flight_multiplier,
			"jump_multiplier": jump_multiplier,
			"damage_multiplier": damage_multiplier
		},
		"inventory": inventory,
		"chest_storages": chest_storages,
		"collected_world_items": collected_world_items,
		"defeated_enemies": defeated_enemies
	}

	var file := File.new()
	var err := file.open(SAVE_FILE_PATH, File.WRITE)
	if err != OK:
		push_error("Failed to open save file for writing: %d" % err)
		notify("Save failed!")
		return false

	file.store_string(to_json(save_dict))
	file.close()
	notify("Game Saved Successfully!")
	return true

func has_save_game() -> bool:
	var file := File.new()
	return file.file_exists(SAVE_FILE_PATH)

func load_game(_tree: Object = null) -> bool:
	var file := File.new()
	if not file.file_exists(SAVE_FILE_PATH):
		notify("No save file found!")
		return false

	if file.open(SAVE_FILE_PATH, File.READ) != OK:
		notify("Error reading save file!")
		return false

	var content := file.get_as_text()
	file.close()

	var parse_res := JSON.parse(content)
	if parse_res.error != OK or typeof(parse_res.result) != TYPE_DICTIONARY:
		notify("Corrupted save data!")
		return false

	var data: Dictionary = parse_res.result

	if data.has("player"):
		var p: Dictionary = data["player"]
		health = float(p.get("health", 100.0))
		max_health = float(p.get("max_health", 100.0))
		current_stamina = float(p.get("stamina", 100.0))
		max_stamina = float(p.get("max_stamina", 100.0))
		ammo = int(p.get("ammo", 30))

	if data.has("cheats"):
		var c: Dictionary = data["cheats"]
		god_mode = bool(c.get("god_mode", false))
		infinite_speed = bool(c.get("infinite_speed", false))
		flight_enabled = bool(c.get("flight_enabled", false))
		speed_multiplier = float(c.get("speed_multiplier", 1.0))
		flight_multiplier = float(c.get("flight_multiplier", 1.0))
		jump_multiplier = float(c.get("jump_multiplier", 1.0))
		damage_multiplier = float(c.get("damage_multiplier", 1.0))

	if data.has("inventory") and typeof(data["inventory"]) == TYPE_ARRAY:
		inventory = data["inventory"]
	if data.has("chest_storages") and typeof(data["chest_storages"]) == TYPE_DICTIONARY:
		chest_storages = data["chest_storages"]
	if data.has("collected_world_items") and typeof(data["collected_world_items"]) == TYPE_DICTIONARY:
		collected_world_items = data["collected_world_items"]
	if data.has("defeated_enemies") and typeof(data["defeated_enemies"]) == TYPE_DICTIONARY:
		defeated_enemies = data["defeated_enemies"]

	pending_load_data = data
	var target_scene: String = str(data.get("scene", "res://Scenes/Main Game.tscn"))
	if target_scene.empty():
		target_scene = "res://Scenes/Main Game.tscn"

	get_tree().paused = false
	var err := get_tree().change_scene(target_scene)
	if err != OK:
		push_error("Failed to change scene during load: %d" % err)
		return false

	emit_signal("stats_changed")
	emit_signal("inventory_changed")
	emit_signal("cheats_changed")
	return true
