extends Area


func _on_Area_body_entered(body): # This function allows the player to jump on an designated area and be launched based on the value set such as the "50" in the second line
	body._velocity += Vector3.UP * 50
