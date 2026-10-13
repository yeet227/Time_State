extends Label

export var update_interval: float = 0.2
var _time_accumulator: float = 0.0

func _ready() -> void:
	var _err := Global.connect("settings_changed", self, "_on_settings_changed")
	_on_settings_changed()

func _on_settings_changed() -> void:
	visible = Global.ShowFPS

func _process(delta: float) -> void:
	if not visible:
		return

	_time_accumulator += delta
	if _time_accumulator >= update_interval:
		_time_accumulator = 0.0
		var fps: int = Engine.get_frames_per_second()
		text = "FPS: %d" % fps
