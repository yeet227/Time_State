extends Button

export(String, FILE, "*.tscn") var scene_to_load: String = ""

func _on_Controls_pressed() -> void:
	if scene_to_load.empty():
		push_warning("SceneChangeButton '%s' has no scene_to_load set." % name)
		return
	var err := get_tree().change_scene(scene_to_load)
	if err != OK:
		push_error("Failed to change scene to '%s', error code: %d" % [scene_to_load, err])
