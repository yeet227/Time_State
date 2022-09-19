extends KinematicBody

var Speed = 6.0
var point = Vector3(10, 10, 0)
var Second_point = Vector3(52, 30, 0)

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
	print(transform)
