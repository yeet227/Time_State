extends AnimationPlayer

var anim = get_node("AnimationPlayer").get_animation("SunRotate")


func _physics_process(delta):
	anim.set_loop(true)
	get_node("AnimationPlayer").play("SunRotate")
