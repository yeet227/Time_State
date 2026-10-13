extends Label

export var update_interval: float = 0.2
var _time_accumulator: float = 0.0

func _ready() -> void:
	# Show or hide based on Global settings if available
	if "ShowFPS" in Global:
		visible = Global.ShowFPS

func _process(delta: float) -> void:
	# Keep visibility in sync with Global.ShowFPS if desired
	if "ShowFPS" in Global and not Global.ShowFPS and not visible:
		return

	_time_accumulator += delta
	if _time_accumulator >= update_interval:
		_time_accumulator = 0.0
		var fps: int = Engine.get_frames_per_second()
		text = "FPS: %d" % fps
