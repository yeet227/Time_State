extends Area



func _on_Area_body_entered(body):
	body._velocity += Vector3.UP * 45
