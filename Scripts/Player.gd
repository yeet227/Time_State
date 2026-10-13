extends KinematicBody

const HUDManagerScript = preload("res://Scripts/HUD_Manager.gd")
const ProjectileScript = preload("res://Scripts/Projectile.gd")

# --- Movement Parameters ---
export var walk_speed: float = 12.0
export var sprint_speed: float = 18.0
export var flight_base_speed: float = 22.0
export var acceleration: float = 10.0
export var jump_impulse: float = 14.0
export var gravity: float = 30.0

# --- Combat Parameters ---
export var base_projectile_damage: float = 25.0
export var fire_cooldown: float = 0.22

# --- Stamina & Health System ---
export var max_health: float = 100.0
export var max_stamina: float = 100.0
export var stamina_drain_rate: float = 25.0
export var stamina_regen_rate: float = 15.0
export var stamina_regen_delay: float = 1.0

var health: float = 100.0
var current_stamina: float = 100.0
var time_since_last_sprint: float = 0.0
var _fire_timer: float = 0.0
var _spawn_transform: Transform

# --- Physics Vectors ---
var velocity: Vector3 = Vector3.ZERO
var snap_vector: Vector3 = Vector3.DOWN

# Property aliases for compatibility with scene overrides and jump pads
var _velocity: Vector3 setget _set_velocity_alias, _get_velocity_alias
var jump_strength: float setget _set_jump_strength, _get_jump_strength

func _set_velocity_alias(v: Vector3) -> void:
	velocity = v

func _get_velocity_alias() -> Vector3:
	return velocity

func _set_jump_strength(v: float) -> void:
	jump_impulse = v

func _get_jump_strength() -> float:
	return jump_impulse

onready var camera_pivot: Spatial = (
	get_node_or_null("CameraPivot") if has_node("CameraPivot")
	else get_node_or_null("SpringArm")
)
onready var stamina_bar: ProgressBar = get_node_or_null("ProgressBar") as ProgressBar

var _hud: CanvasLayer = null
var _nearby_chest: Spatial = null

func _ready() -> void:
	add_to_group("player")
	_spawn_transform = global_transform

	# Hide legacy bare ProgressBar in favor of HUD_Manager
	if stamina_bar:
		stamina_bar.visible = false

	# Instantiate HUD Manager if none exists
	var existing_huds := get_tree().get_nodes_in_group("hud")
	if existing_huds.empty():
		_hud = CanvasLayer.new()
		_hud.set_script(HUDManagerScript)
		_hud.player_node = self
		add_child(_hud)
	else:
		_hud = existing_huds[0] as CanvasLayer
		if "player_node" in _hud:
			_hud.player_node = self

	# Restore from Global state or pending save load
	if not Global.pending_load_data.empty():
		var p_data: Dictionary = Global.pending_load_data.get("player", {})
		if p_data.has("x") and p_data.has("y") and p_data.has("z"):
			global_transform.origin = Vector3(float(p_data["x"]), float(p_data["y"]), float(p_data["z"]))
		if p_data.has("rot_y"):
			rotation.y = float(p_data["rot_y"])
		Global.pending_load_data.clear()
		Global.notify("Save Game Loaded!")

	max_health = Global.max_health
	health = Global.health
	max_stamina = Global.max_stamina
	current_stamina = Global.current_stamina

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.scancode == KEY_E:
			if _nearby_chest and is_instance_valid(_nearby_chest) and _hud:
				var c_id: String = _nearby_chest.get("chest_id") if "chest_id" in _nearby_chest else _nearby_chest.name
				var c_title: String = _nearby_chest.get("chest_title") if "chest_title" in _nearby_chest else "Supply Chest"
				_hud.call("open_inventory", c_id, c_title)
				get_tree().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if _fire_timer > 0.0:
		_fire_timer -= delta

	# 1. Handle Horizontal Movement Inputs
	var input_dir := Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		input_dir.z -= 1.0
	if Input.is_action_pressed("move_back") or Input.is_action_pressed("move_backward"):
		input_dir.z += 1.0
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1.0
	if input_dir.length_squared() > 1.0:
		input_dir = input_dir.normalized()

	var is_moving := input_dir.length_squared() > 0.01
	var is_trying_sprint := Input.is_action_pressed("Stamina")

	# 2. Check Flight Mode vs Ground Movement
	if Global.flight_enabled:
		_process_flight_movement(input_dir, is_trying_sprint, delta)
	else:
		_process_ground_movement(input_dir, is_moving, is_trying_sprint, delta)

	# 3. Sync Stamina & Health to Global
	if Global.god_mode or Global.infinite_speed:
		current_stamina = max_stamina
	Global.current_stamina = current_stamina
	Global.health = health

	# 4. Handle Ranged Shooting (when mouse is captured)
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if (Input.is_action_pressed("Aim") or Input.is_action_pressed("Fire")) and _fire_timer <= 0.0:
			_shoot_projectile()

	# 5. Check Nearby Interactable Chests
	_update_nearby_interactables()

func _process_flight_movement(input_dir: Vector3, is_boosting: bool, delta: float) -> void:
	snap_vector = Vector3.ZERO
	var fly_dir := Vector3.ZERO
	if camera_pivot:
		fly_dir = camera_pivot.global_transform.basis.xform(input_dir)
	else:
		fly_dir = input_dir

	if Input.is_action_pressed("jump"):
		fly_dir.y += 1.0
	if Input.is_key_pressed(KEY_CONTROL) or Input.is_key_pressed(KEY_C):
		fly_dir.y -= 1.0

	if fly_dir.length_squared() > 0.01:
		fly_dir = fly_dir.normalized()

	var fly_speed := flight_base_speed * Global.flight_multiplier * Global.speed_multiplier
	if is_boosting:
		fly_speed *= 1.65

	var accel := (acceleration * 2.0) if Global.infinite_speed else acceleration
	velocity = velocity.linear_interpolate(fly_dir * fly_speed, min(1.0, accel * delta))
	velocity = move_and_slide(velocity, Vector3.UP)

func _process_ground_movement(input_dir: Vector3, is_moving: bool, is_trying_sprint: bool, delta: float) -> void:
	var move_dir := input_dir
	if camera_pivot:
		move_dir = camera_pivot.global_transform.basis.xform(input_dir)
		move_dir.y = 0.0
		if move_dir.length_squared() > 0.001:
			move_dir = move_dir.normalized()

	var is_sprinting := false
	if is_trying_sprint and is_moving and (current_stamina > 0.0 or Global.god_mode or Global.infinite_speed):
		is_sprinting = true
		if not Global.god_mode and not Global.infinite_speed:
			current_stamina = max(0.0, current_stamina - stamina_drain_rate * delta)
		time_since_last_sprint = 0.0
	else:
		time_since_last_sprint += delta
		if time_since_last_sprint >= stamina_regen_delay:
			current_stamina = min(max_stamina, current_stamina + stamina_regen_rate * delta)

	var base_spd := sprint_speed if is_sprinting else walk_speed
	var target_speed := base_spd * Global.speed_multiplier * (1.4 if Global.infinite_speed else 1.0)
	var target_velocity := move_dir * target_speed

	var accel := (acceleration * 2.5) if Global.infinite_speed else acceleration
	velocity.x = lerp(velocity.x, target_velocity.x, min(1.0, accel * delta))
	velocity.z = lerp(velocity.z, target_velocity.z, min(1.0, accel * delta))

	if is_on_floor():
		snap_vector = -get_floor_normal()
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_impulse * Global.jump_multiplier
			snap_vector = Vector3.ZERO
		else:
			velocity.y = -0.1
	else:
		velocity.y -= gravity * delta
		snap_vector = Vector3.ZERO

	velocity = move_and_slide_with_snap(velocity, snap_vector, Vector3.UP, true, 4, deg2rad(45.0))

func _shoot_projectile() -> void:
	if not Global.god_mode:
		if Global.ammo <= 0:
			_fire_timer = 0.4
			Global.notify("Out of Energy Ammo! Pick up Ammo Cells or use Inventory.")
			return
		Global.ammo -= 1

	_fire_timer = fire_cooldown

	var aim_basis := global_transform.basis
	var spawn_pos := global_transform.origin + Vector3(0.0, 1.2, 0.0)
	if camera_pivot and camera_pivot.has_node("Camera"):
		var cam: Camera = camera_pivot.get_node("Camera")
		aim_basis = cam.global_transform.basis
	elif camera_pivot:
		aim_basis = camera_pivot.global_transform.basis

	var shoot_dir := (-aim_basis.z).normalized()
	spawn_pos += shoot_dir * 1.1

	var proj := Area.new()
	proj.set_script(ProjectileScript)
	proj.shooter = self
	proj.is_enemy_projectile = false
	proj.damage = base_projectile_damage * Global.damage_multiplier
	proj.speed = 46.0
	proj.direction = shoot_dir

	var scene_root := get_tree().current_scene if get_tree().current_scene else get_parent()
	scene_root.add_child(proj)
	proj.global_transform.origin = spawn_pos

func _update_nearby_interactables() -> void:
	_nearby_chest = null
	var chests := get_tree().get_nodes_in_group("chest")
	var best_dist := 4.5
	for c in chests:
		if c is Spatial and is_instance_valid(c):
			var d := global_transform.origin.distance_to(c.global_transform.origin)
			if d <= best_dist:
				best_dist = d
				_nearby_chest = c

	if _hud:
		if _nearby_chest:
			var title: String = _nearby_chest.get("chest_title") if "chest_title" in _nearby_chest else "Supply Chest"
			_hud.call("set_interaction_prompt", "[E] Open %s" % title)
		else:
			_hud.call("set_interaction_prompt", "")

func take_damage(amount: float, source_pos: Vector3 = Vector3.ZERO) -> void:
	if Global.god_mode:
		return

	health = max(0.0, health - amount)
	Global.health = health
	if _hud:
		_hud.call("trigger_damage_flash")

	if source_pos != Vector3.ZERO:
		var push_dir := (global_transform.origin - source_pos)
		push_dir.y = 0.0
		if push_dir.length_squared() > 0.01:
			velocity += push_dir.normalized() * 8.0 + Vector3.UP * 4.0

	if health <= 0.0:
		_respawn()

func _respawn() -> void:
	health = max_health
	current_stamina = max_stamina
	Global.health = health
	Global.current_stamina = current_stamina
	velocity = Vector3.ZERO
	global_transform = _spawn_transform
	Global.notify("You were defeated! Respawned at checkpoint.")