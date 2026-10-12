extends KinematicBody

# --- Movement Parameters ---
export var walk_speed: float = 12.0
export var sprint_speed: float = 18.0
export var acceleration: float = 10.0
export var jump_impulse: float = 14.0
export var gravity: float = 30.0

# --- Stamina System ---
export var max_stamina: float = 100.0
export var stamina_drain_rate: float = 25.0   # Drain per second while sprinting
export var stamina_regen_rate: float = 15.0   # Regen per second while resting
export var stamina_regen_delay: float = 1.0   # Seconds before regen starts after sprinting

var current_stamina: float = 100.0
var time_since_last_sprint: float = 0.0

# --- Physics Vectors ---
var velocity: Vector3 = Vector3.ZERO
var snap_vector: Vector3 = Vector3.DOWN

onready var camera_pivot: Spatial = $CameraPivot # Adjust path to match your scene

func _ready() -> void:
	current_stamina = max_stamina

func _physics_process(delta: float) -> void:
	# 1. Handle Horizontal Movement Inputs
	var input_dir := Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		input_dir.z -= 1.0
	if Input.is_action_pressed("move_backward"):
		input_dir.z += 1.0
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1.0
	input_dir = input_dir.normalized()

	# Align input relative to camera view if pivot exists
	var move_dir := input_dir
	if camera_pivot:
		move_dir = camera_pivot.global_transform.basis.xform(input_dir)
		move_dir.y = 0.0
		move_dir = move_dir.normalized()

	# 2. Sprint & Stamina Logic
	var is_moving := input_dir.length_squared() > 0.01
	var is_trying_sprint := Input.is_action_pressed("Stamina")
	var is_sprinting := false

	if is_trying_sprint and is_moving and current_stamina > 0.0:
		is_sprinting = true
		current_stamina = max(0.0, current_stamina - stamina_drain_rate * delta)
		time_since_last_sprint = 0.0
	else:
		time_since_last_sprint += delta
		if time_since_last_sprint >= stamina_regen_delay:
			current_stamina = min(max_stamina, current_stamina + stamina_regen_rate * delta)

	# 3. Velocity Interpolation
	var target_speed := sprint_speed if is_sprinting else walk_speed
	var target_velocity := move_dir * target_speed
	
	velocity.x = lerp(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = lerp(velocity.z, target_velocity.z, acceleration * delta)

	# 4. Vertical Movement & Gravity
	if is_on_floor():
		snap_vector = -get_floor_normal()
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_impulse
			snap_vector = Vector3.ZERO # Disable snapping when jumping
		else:
			velocity.y = -0.1 # Keep grounded
	else:
		velocity.y -= gravity * delta
		snap_vector = Vector3.ZERO

	# 5. Move and Slide with snap
	velocity = move_and_slide_with_snap(velocity, snap_vector, Vector3.UP, true, 4, deg2rad(45.0))