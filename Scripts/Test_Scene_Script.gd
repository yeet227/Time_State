extends Spatial

onready var player: Spatial = get_node_or_null("Player") as Spatial

func _ready() -> void:
	# Link player target to any existing Enemy instances in the test scene
	if player:
		for child in get_children():
			if child.has_method("set_target"):
				child.call("set_target", player)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.scancode == KEY_ESCAPE:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			var _err = get_tree().change_scene("res://Scenes/Main Menu.tscn")
		elif event.scancode == KEY_R:
			var _err = get_tree().reload_current_scene()
