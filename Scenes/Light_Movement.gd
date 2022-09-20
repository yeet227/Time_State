extends DirectionalLight

var Speed = 8.0
var point = Vector3(10, 153.0, -128.8)

func _process(delta):
	var direction
	
	if point.distance_to(transform.origin) > 0.05:
		direction = point - transform.origin
		direction = direction.normalized() * Speed
	else:
		direction = point - transform.origin
	#print(transform)
		
