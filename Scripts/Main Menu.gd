extends Control

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func change_to_scene(scene_path: String) -> void:
	if scene_path.empty():
		push_warning("Attempted to load empty scene path.")
		return
	var err := get_tree().change_scene(scene_path)
	if err != OK:
		push_error("Failed to load scene '%s', error: %d" % [scene_path, err])
