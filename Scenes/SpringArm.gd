extends SpringArm

export var mouse_sensitivity := 0.10

var _camera_height_offset := Vector3(0.0, 1.30422, 0.0)

func _ready() -> void:
	set_as_toplevel(true)
	if get_parent() is CollisionObject:
		add_excluded_object(get_parent().get_rid())
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	var _err := Global.connect("settings_changed", self, "_apply_camera_settings")
	_apply_camera_settings()
	var p := get_parent() as Spatial
	if p:
		global_transform.origin = p.global_transform.origin + _camera_height_offset

func _apply_camera_settings() -> void:
	mouse_sensitivity = Global.mouse_sensitivity
	if has_node("Camera") and $Camera is Camera:
		($Camera as Camera).fov = Global.fov

func _physics_process(_delta: float) -> void:
	var p := get_parent() as Spatial
	if p and is_instance_valid(p):
		global_transform.origin = p.global_transform.origin + _camera_height_offset

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotation_degrees.x -= event.relative.y * mouse_sensitivity
		rotation_degrees.x = clamp(rotation_degrees.x, -90.0, 30.0)
		
		rotation_degrees.y -= event.relative.x * mouse_sensitivity
		rotation_degrees.y = wrapf(rotation_degrees.y, 0.0, 360.0)
