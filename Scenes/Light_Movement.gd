extends DirectionalLight

var Speed = 125.0
var point = Vector3(10, 10, 0)
var Interaction_Delay = 7.0
var Second_Delay = 3.0

func _process(delta):
	var direction
	
	if point.distance_to(transform.origin) > 0.05:
		direction = point - transform.origin
		direction = direction.normalized() * Speed
	else:
		direction = point - transform.origin
	#print(transform)
		
