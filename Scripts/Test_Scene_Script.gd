extends Spatial

const EnemyScene = preload("res://Scenes/Enemy_NPC.tscn")

onready var player: Spatial = get_node_or_null("Player") as Spatial

func _ready() -> void:
	var found_enemy := false
	for child in get_children():
		if child.has_method("set_target"):
			found_enemy = true
			if player:
				child.call("set_target", player)

	if not found_enemy:
		var positions := [
			Vector3(-8.0, 2.5, -6.0),
			Vector3(8.0, 2.5, -6.0)
		]
		for i in range(positions.size()):
			var enemy := EnemyScene.instance()
			enemy.enemy_id = "test_scene_enemy_%d" % i
			add_child(enemy)
			enemy.global_transform.origin = positions[i]
			if player and enemy.has_method("set_target"):
				enemy.call("set_target", player)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.scancode == KEY_R:
			var _err = get_tree().reload_current_scene()
