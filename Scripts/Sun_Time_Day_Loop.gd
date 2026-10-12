extends AnimationPlayer

export var animation_name: String = "SunRotate"
export var play_speed: float = 1.0

func _ready() -> void:
	if has_animation(animation_name):
		var anim = get_animation(animation_name)
		anim.loop = true # Enforce continuous loop
		play(animation_name, -1, play_speed)
	else:
		push_warning("Animation '%s' not found on Sun AnimationPlayer." % animation_name)