extends KinematicBody

var Speed = 10.0 #The speed at which the enemy is travelling to the designated Vector
var point = Vector3(10, 10, 0) #The place where Enemy is traveling too
var Interaction_Delay = 7.0 #Time between the dialogue being output for the first part of dialogue
var Second_Delay = 5.0 #Time between the dialogue being output for the second part of dialogue

func _process(delta): #this part of the code is meant to remove any point of overshoot within the enemy traveling a certain distance befoore stopping.
	var direction
	
	if point.distance_to(transform.origin) > 0.05:
		direction = point - transform.origin
		direction = direction.normalized() * Speed
	else:
		direction = point - transform.origin
	move_and_slide(direction)
	print(transform)
		


func _on_Area_body_entered(KinematicBody): # this part of the script has been made to create an output in the logs to interact with the player
	yield(get_tree().create_timer(Interaction_Delay),"timeout") #Delay between the player entering area and the warning
	print("I Would Move Out Of The Way If I Was You") #the dialogue that is outputted after a set time
	yield(get_tree().create_timer(Second_Delay),"timeout") #Delay between the player entering area before being shot 
	print("Bang!!") #the dialogue that is outputted after a set time
