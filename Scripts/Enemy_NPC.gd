extends KinematicBody

var Speed = 10.0
var point = Vector3(10, 10, 0)
var Interaction_Delay = 7.0
var Second_Delay = 5.0

func _process(delta):
	var direction
	
	if point.distance_to(transform.origin) > 0.05:
		direction = point - transform.origin
		direction = direction.normalized() * Speed
	else:
		direction = point - transform.origin
	move_and_slide(direction)
	print(transform)
		


func _on_Area_body_entered(KinematicBody):
	yield(get_tree().create_timer(Interaction_Delay),"timeout")
	print("I Would Move Out Of The Way If I Was You")
	yield(get_tree().create_timer(Second_Delay),"timeout")
	print("Bang!!")
