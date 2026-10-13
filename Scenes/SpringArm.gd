extends SpringArm

export var mouse_sensitivity := 0.10

func _ready() -> void:
	set_as_toplevel(false)
	if get_parent() is CollisionObject:
		add_excluded_object(get_parent().get_rid())
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	var _err := Global.connect("settings_changed", self, "_apply_camera_settings")
	_apply_camera_settings()

func _apply_camera_settings() -> void:
	mouse_sensitivity = Global.mouse_sensitivity
	if has_node("Camera") and $Camera is Camera:
		($Camera as Camera).fov = Global.fov

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotation_degrees.x -= event.relative.y * mouse_sensitivity
		rotation_degrees.x = clamp(rotation_degrees.x, -90.0, 30.0)
		
		rotation_degrees.y -= event.relative.x * mouse_sensitivity
		rotation_degrees.y = wrapf(rotation_degrees.y, 0.0, 360.0)
