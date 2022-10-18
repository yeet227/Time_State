extends KinematicBody

export var jump_strength = 1.0004 #Character force of jump
export var gravity = 125.807 #Character Gravity
export var speed = 18.0 #Character Speed
export var Stamina_Delay : float = 10.0 #How many Seconds between stamina use
export var Stamina_Length : float = 25.0 #Length of time for the use of stamina to be in effect
var Stamina = false
var Health = 35

var _velocity := Vector3.ZERO
var _snap_vector := Vector3.DOWN

onready var _spring_arm: SpringArm = $SpringArm

func _physics_process(delta):
	var move_direction := Vector3.ZERO
	move_direction.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	move_direction.z = Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	move_direction = move_direction.rotated(Vector3.UP, _spring_arm.rotation.y).normalized() 
	_velocity.x = move_direction.x * speed
	_velocity.z = move_direction.z * speed
	_velocity.y -= gravity * delta
	
	var just_landed := is_on_floor() and _snap_vector == Vector3.ZERO
	var is_jumping := is_on_floor() and Input.is_action_just_pressed("jump")
	if is_jumping:
		_velocity.y = jump_strength
		_snap_vector = Vector3.ZERO
	elif just_landed:
		_snap_vector = Vector3.DOWN
	_velocity = move_and_slide_with_snap(_velocity, _snap_vector, Vector3.UP, true)
	
	if _velocity.length() > 0.2:
		var look_direction = Vector2(_velocity.z, _velocity.x)
	

func _process(delta):
	_spring_arm.translation = translation
	if Input.is_action_pressed("Stamina"):
		Stamina = true
		speed = 45.0
		print(speed) # Speedometer for Output Logging Purposes
		yield(get_tree().create_timer(Stamina_Length),"timeout")
		Input.is_action_just_released("Stamina")
		Stamina = false
		speed = 18.0
		print(speed) #Speedometer for Logging Purposes
