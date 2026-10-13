extends Spatial

export var chest_id: String = "world_chest_1"
export var chest_title: String = "Supply Chest"
export var interaction_distance: float = 4.5

func _ready() -> void:
	add_to_group("chest")
	if chest_id.empty():
		chest_id = "chest_%s" % name
	Global.ensure_chest_initialized(chest_id)

func is_player_in_range(player: Spatial) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	return global_transform.origin.distance_to(player.global_transform.origin) <= interaction_distance
