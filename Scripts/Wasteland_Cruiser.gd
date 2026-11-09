extends KinematicBody

const DamageFlashColor := Color(1.0, 0.4, 0.1, 1.0)

export var vehicle_id: String = "wasteland_cruiser_1"
export var vehicle_name: String = "Wasteland Cruiser"
export var max_speed: float = 32.0          # ~115 km/h
export var boost_speed: float = 50.0        # ~180 km/h
export var reverse_speed: float = 14.0
export var acceleration: float = 20.0
export var boost_accel: float = 42.0
export var braking_force: float = 28.0
export var turn_speed: float = 2.5
export var steer_limit: float = deg2rad(32.0)
export var gravity: float = 30.0
export var ram_damage_factor: float = 3.2
export var enter_distance: float = 4.5

var current_speed: float = 0.0
var current_steer: float = 0.0
var velocity: Vector3 = Vector3.ZERO
var is_driven: bool = false
var driver_player: Spatial = null

var nitro_fuel: float = 100.0
var max_nitro: float = 100.0
var nitro_drain_rate: float = 32.0
var nitro_regen_rate: float = 14.0
var is_boosting: bool = false

# Visual nodes
onready var visual_pivot: Spatial = get_node_or_null("VisualPivot")
onready var spring_arm: SpringArm = get_node_or_null("SpringArm")
onready var chase_camera: Camera = get_node_or_null("SpringArm/Camera") if has_node("SpringArm/Camera") else null
onready var headlights: Spatial = get_node_or_null("Headlights")
onready var exhaust_particles: CPUParticles = get_node_or_null("ExhaustParticles")

# Wheels references in race.fbx
var _wheel_fl: Spatial = null
var _wheel_fr: Spatial = null
var _wheel_rl: Spatial = null
var _wheel_rr: Spatial = null
var _wheel_spin: float = 0.0

func _ready() -> void:
	add_to_group("vehicle")
	add_to_group("interactable")
	_find_wheel_nodes()
	if headlights:
		headlights.visible = true

func _find_wheel_nodes() -> void:
	if visual_pivot:
		_wheel_fl = visual_pivot.find_node("wheel_frontLeft", true, false) as Spatial
		_wheel_fr = visual_pivot.find_node("wheel_frontRight", true, false) as Spatial
		_wheel_rl = visual_pivot.find_node("wheel_backLeft", true, false) as Spatial
		_wheel_rr = visual_pivot.find_node("wheel_backRight", true, false) as Spatial

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.scancode == KEY_E:
			if is_driven:
				exit_vehicle()
				get_tree().set_input_as_handled()
			else:
				var players := get_tree().get_nodes_in_group("player")
				if not players.empty():
					var p := players[0] as Spatial
					if p and is_instance_valid(p) and global_transform.origin.distance_to(p.global_transform.origin) <= enter_distance:
						enter_vehicle(p)
						get_tree().set_input_as_handled()

		elif event.scancode == KEY_R and is_driven:
			reset_orientation()
			Global.notify("Wasteland Cruiser uprighted!")
			get_tree().set_input_as_handled()

	elif event is InputEventMouseMotion and is_driven and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if spring_arm:
			spring_arm.rotation_degrees.x -= event.relative.y * Global.mouse_sensitivity
			spring_arm.rotation_degrees.x = clamp(spring_arm.rotation_degrees.x, -50.0, 20.0)
			spring_arm.rotation_degrees.y -= event.relative.x * Global.mouse_sensitivity
			spring_arm.rotation_degrees.y = wrapf(spring_arm.rotation_degrees.y, 0.0, 360.0)

func _physics_process(delta: float) -> void:
	if is_driven:
		_process_driving(delta)
	else:
		_process_parked(delta)

	_update_wheel_animations(delta)

func _process_driving(delta: float) -> void:
	var forward_input := 0.0
	if Input.is_action_pressed("move_forward"):
		forward_input += 1.0
	if Input.is_action_pressed("move_backward") or Input.is_action_pressed("move_back"):
		forward_input -= 1.0

	var steer_input := 0.0
	if Input.is_action_pressed("move_left"):
		steer_input += 1.0
	if Input.is_action_pressed("move_right"):
		steer_input -= 1.0

	var is_handbraking := Input.is_action_pressed("jump")
	var is_trying_boost := Input.is_action_pressed("Stamina") and forward_input > 0.0

	# 1. Nitro management
	is_boosting = false
	if is_trying_boost and nitro_fuel > 2.0:
		is_boosting = true
		nitro_fuel = max(0.0, nitro_fuel - nitro_drain_rate * delta)
	else:
		nitro_fuel = min(max_nitro, nitro_fuel + nitro_regen_rate * delta)

	if exhaust_particles:
		exhaust_particles.emitting = is_boosting

	# 2. Acceleration and speed calculation
	var target_max := (boost_speed if is_boosting else max_speed) * Global.speed_multiplier
	var target_speed := forward_input * target_max

	if is_handbraking:
		current_speed = lerp(current_speed, 0.0, min(1.0, braking_force * 1.5 * delta))
	elif forward_input != 0.0:
		var accel := boost_accel if is_boosting else acceleration
		current_speed = lerp(current_speed, target_speed, min(1.0, accel * delta))
	else:
		# Natural drag
		current_speed = lerp(current_speed, 0.0, min(1.0, 8.0 * delta))

	# 3. Steering and Rotation
	var speed_ratio := clamp(abs(current_speed) / max_speed, 0.0, 1.0)
	var steer_rate := turn_speed * (1.2 if is_handbraking else 1.0)
	current_steer = lerp(current_steer, steer_input * steer_limit, min(1.0, 10.0 * delta))

	if abs(current_speed) > 0.5:
		var turn_direction := 1.0 if current_speed >= 0.0 else -1.0
		var rot_amount := steer_input * steer_rate * delta * turn_direction * (0.4 + 0.6 * speed_ratio)
		rotate_object_local(Vector3.UP, rot_amount)

	# 4. Movement vectors and terrain projection
	var forward_dir := -transform.basis.z.normalized()
	velocity.x = forward_dir.x * current_speed
	velocity.z = forward_dir.z * current_speed

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = forward_dir.y * current_speed - 1.0
		_align_with_terrain(delta)

	var snap := -get_floor_normal() if is_on_floor() else Vector3.DOWN
	velocity = move_and_slide_with_snap(velocity, snap, Vector3.UP, true, 4, deg2rad(45.0))

	# Keep driver player position synchronized with cruiser
	if driver_player and is_instance_valid(driver_player):
		driver_player.global_transform.origin = global_transform.origin

	# 5. Check ramming impacts with enemies
	_check_ram_collisions()

	# 6. Update Dynamic Camera FOV based on speed
	if chase_camera:
		var fov_boost := 18.0 if is_boosting else (speed_ratio * 8.0)
		chase_camera.fov = lerp(chase_camera.fov, Global.fov + fov_boost, min(1.0, 6.0 * delta))

func _align_with_terrain(delta: float) -> void:
	var floor_normal := get_floor_normal()
	if floor_normal.length_squared() > 0.01 and floor_normal.dot(Vector3.UP) > 0.35:
		var target_up := floor_normal
		var cur_up := transform.basis.y
		var new_up := cur_up.linear_interpolate(target_up, min(1.0, 8.0 * delta)).normalized()
		var forward := -transform.basis.z
		var right := forward.cross(new_up)
		if right.length_squared() > 0.001:
			right = right.normalized()
			forward = new_up.cross(right).normalized()
			transform.basis = Basis(right, new_up, -forward)

func _check_ram_collisions() -> void:
	var abs_spd := abs(current_speed)
	if abs_spd < 6.0:
		return

	var slides := get_slide_count()
	for i in range(slides):
		var col := get_slide_collision(i)
		var collider := col.collider
		if collider and collider.is_in_group("enemy") and collider.has_method("take_damage"):
			var damage := abs_spd * ram_damage_factor * Global.damage_multiplier
			collider.call("take_damage", damage, global_transform.origin)
			Global.notify("CRUNCH! Cruiser rammed enemy for %d damage!" % int(damage))
			current_speed *= 0.65 # Impact slowdown
			break

func _process_parked(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.1
	velocity.x = lerp(velocity.x, 0.0, min(1.0, 8.0 * delta))
	velocity.z = lerp(velocity.z, 0.0, min(1.0, 8.0 * delta))
	velocity = move_and_slide_with_snap(velocity, Vector3.DOWN, Vector3.UP, true)

func _update_wheel_animations(delta: float) -> void:
	_wheel_spin += (current_speed / 0.4) * delta
	if _wheel_fl and is_instance_valid(_wheel_fl):
		_wheel_fl.rotation = Vector3(_wheel_spin, current_steer, 0.0)
	if _wheel_fr and is_instance_valid(_wheel_fr):
		_wheel_fr.rotation = Vector3(_wheel_spin, current_steer, 0.0)
	if _wheel_rl and is_instance_valid(_wheel_rl):
		_wheel_rl.rotation = Vector3(_wheel_spin, 0.0, 0.0)
	if _wheel_rr and is_instance_valid(_wheel_rr):
		_wheel_rr.rotation = Vector3(_wheel_spin, 0.0, 0.0)

func enter_vehicle(player: Spatial) -> void:
	if is_driven or player == null or not is_instance_valid(player):
		return

	driver_player = player
	is_driven = true
	Global.is_driving = true
	Global.current_vehicle = self

	# Disable player visuals & collisions
	driver_player.visible = false
	if driver_player is CollisionObject:
		(driver_player as CollisionObject).collision_layer = 0
		(driver_player as CollisionObject).collision_mask = 0

	# Transfer camera to Cruiser
	if chase_camera:
		chase_camera.current = true
		if spring_arm:
			spring_arm.rotation_degrees = Vector3(-12.0, 0.0, 0.0)

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	Global.notify("Entered Wasteland Cruiser! [W/S] Drive | [A/D] Steer | [Space] Drift | [Shift] Nitro | [E] Exit")
	Global.emit_signal("vehicle_state_changed", true, self)

func exit_vehicle() -> void:
	if not is_driven or driver_player == null or not is_instance_valid(driver_player):
		is_driven = false
		Global.is_driving = false
		Global.current_vehicle = null
		return

	# Place player beside driver door
	var exit_offset := transform.basis.x * -2.4 + Vector3.UP * 0.5
	driver_player.global_transform.origin = global_transform.origin + exit_offset
	driver_player.visible = true

	if driver_player is CollisionObject:
		(driver_player as CollisionObject).collision_layer = 1
		(driver_player as CollisionObject).collision_mask = 1

	# Restore player camera
	var p_cam: Camera = driver_player.find_node("Camera", true, false) as Camera
	if p_cam:
		p_cam.current = true
	elif chase_camera:
		chase_camera.current = false

	is_driven = false
	current_speed = 0.0
	Global.is_driving = false
	Global.current_vehicle = null
	Global.notify("Exited Wasteland Cruiser.")
	Global.emit_signal("vehicle_state_changed", false, null)
	driver_player = null

func reset_orientation() -> void:
	var cur_rot_y := rotation.y
	rotation = Vector3(0.0, cur_rot_y, 0.0)
	global_transform.origin.y += 1.8
	velocity = Vector3.ZERO
	current_speed = 0.0
