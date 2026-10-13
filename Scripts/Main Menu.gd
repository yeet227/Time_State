extends Control

func _ready() -> void:
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_setup_extra_buttons()

func _setup_extra_buttons() -> void:
	if not has_node("Label"):
		return
	var label_node := $Label
	if not label_node.has_node("Load_Save_Button"):
		var load_btn := Button.new()
		load_btn.name = "Load_Save_Button"
		load_btn.text = "Load Saved Game"
		load_btn.margin_left = 100.0
		load_btn.margin_top = 138.0
		load_btn.margin_right = 383.0
		load_btn.margin_bottom = 250.0
		var _err := load_btn.connect("pressed", self, "_on_Load_Save_pressed")
		label_node.add_child(load_btn)

	if not label_node.has_node("Quit_Button"):
		var quit_btn := Button.new()
		quit_btn.name = "Quit_Button"
		quit_btn.text = "Quit"
		quit_btn.margin_left = -356.0
		quit_btn.margin_top = 315.0
		quit_btn.margin_right = -73.0
		quit_btn.margin_bottom = 403.0
		var _err2 := quit_btn.connect("pressed", self, "_on_Quit_pressed")
		label_node.add_child(quit_btn)

func _on_Load_Save_pressed() -> void:
	var _ok := Global.load_game()

func _on_Quit_pressed() -> void:
	get_tree().quit()

func change_to_scene(scene_path: String) -> void:
	if scene_path.empty():
		push_warning("Attempted to load empty scene path.")
		return
	var err := get_tree().change_scene(scene_path)
	if err != OK:
		push_error("Failed to load scene '%s', error: %d" % [scene_path, err])
