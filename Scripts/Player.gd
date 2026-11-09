extends KinematicBody

const HUDManagerScript = preload("res://Scripts/HUD_Manager.gd")
const ProjectileScript = preload("res://Scripts/Projectile.gd")
const SwordMeshResource = preload("res://Assets/Blender Assets/Weapons/Sword_Weapon.obj")
const AxeSceneResource = preload("res://Assets/Blender Assets/Weapons/Axe_Prototype.glb")

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
var _melee_swing_timer: float = 0.0
var _melee_swing_duration: float = 0.28
var _is_melee_swinging: bool = false
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
var _nearby_vehicle: Spatial = null

# Avenue 4 Weapon Nodes
var _weapon_pivot: Spatial = null
var _blaster_node: Spatial = null
var _sword_node: Spatial = null
var _axe_node: Spatial = null

func _ready() -> void:
	add_to_group("player")
	_spawn_transform = global_transform

	if stamina_bar:
		stamina_bar.visible = false

	# Setup Weapon Roster & Mounts
	_setup_weapon_mounts()

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

	# Connect global events
	var _err_w := Global.connect("weapon_changed", self, "_on_global_weapon_changed")

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

	_update_weapon_visuals()

func _setup_weapon_mounts() -> void:
	_weapon_pivot = Spatial.new()
	_weapon_pivot.name = "WeaponPivot"
	# Position in right-hand grip area forward of the capsule body
	_weapon_pivot.translation = Vector3(0.42, 0.85, -0.72)
	add_child(_weapon_pivot)

	# 1. Energy Blaster (reparent or create from Movable_object_Anim)
	if has_node("Movable_object_Anim"):
		var orig_gun = get_node("Movable_object_Anim")
		var orig_tf: Transform = orig_gun.transform
		remove_child(orig_gun)
		_weapon_pivot.add_child(orig_gun)
		orig_gun.transform = orig_tf
		orig_gun.translation = Vector3.ZERO
		_blaster_node = orig_gun
	else:
		_blaster_node = Spatial.new()
		_weapon_pivot.add_child(_blaster_node)

	# 2. Wasteland Sword
	var sword_mesh_inst := MeshInstance.new()
	sword_mesh_inst.name = "SwordMesh"
	sword_mesh_inst.mesh = SwordMeshResource
	var sword_mat := SpatialMaterial.new()
	sword_mat.albedo_color = Color(0.85, 0.88, 0.95)
	sword_mat.metallic = 0.85
	sword_mat.roughness = 0.25
	sword_mesh_inst.material_override = sword_mat
	sword_mesh_inst.scale = Vector3(0.065, 0.065, 0.065)
	sword_mesh_inst.rotation_degrees = Vector3(80, 0, -15)
	sword_mesh_inst.translation = Vector3(0.0, -0.4, 0.2)
	_weapon_pivot.add_child(sword_mesh_inst)
	_sword_node = sword_mesh_inst

	# 3. Scrapper Battleaxe
	var axe_inst: Spatial = AxeSceneResource.instance() as Spatial
	axe_inst.name = "AxeInstance"
	axe_inst.scale = Vector3(0.18, 0.18, 0.18)
	axe_inst.rotation_degrees = Vector3(80, -20, 0)
	axe_inst.translation = Vector3(0.0, -0.45, 0.15)
	_weapon_pivot.add_child(axe_inst)
	_axe_node = axe_inst

func _on_global_weapon_changed(_new_id: String) -> void:
	_update_weapon_visuals()

func _update_weapon_visuals() -> void:
	if _blaster_node:
		_blaster_node.visible = (Global.active_weapon == Global.WEAPON_BLASTER)
	if _sword_node:
		_sword_node.visible = (Global.active_weapon == Global.WEAPON_SWORD)
	if _axe_node:
		_axe_node.visible = (Global.active_weapon == Global.WEAPON_AXE)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# Weapon Hotkeys (1, 2, 3)
		if event.scancode == KEY_1:
			Global.set_active_weapon(Global.WEAPON_BLASTER)
			get_tree().set_input_as_handled()
		elif event.scancode == KEY_2:
			Global.set_active_weapon(Global.WEAPON_SWORD)
			get_tree().set_input_as_handled()
		elif event.scancode == KEY_3:
			Global.set_active_weapon(Global.WEAPON_AXE)
			get_tree().set_input_as_handled()

		# Chrono Dilation / Bullet Time Toggle (Q)
		elif event.scancode == KEY_Q:
			var _active := Global.toggle_chrono_dilation()
			get_tree().set_input_as_handled()

		# Interaction / Drive Vehicle / Open Chest (E)
		elif event.scancode == KEY_E:
			if _nearby_vehicle and is_instance_valid(_nearby_vehicle):
				_nearby_vehicle.call("enter_vehicle", self)
				get_tree().set_input_as_handled()
			elif _nearby_chest and is_instance_valid(_nearby_chest) and _hud:
				var c_id: String = _nearby_chest.get("chest_id") if "chest_id" in _nearby_chest else _nearby_chest.name
				var c_title: String = _nearby_chest.get("chest_title") if "chest_title" in _nearby_chest else "Supply Chest"
				_hud.call("open_inventory", c_id, c_title)
				get_tree().set_input_as_handled()

	elif event is InputEventMouseButton and event.pressed:
		# Mouse Wheel Weapon Cycling
		if event.button_index == BUTTON_WHEEL_UP:
			Global.cycle_weapon(-1)
			get_tree().set_input_as_handled()
		elif event.button_index == BUTTON_WHEEL_DOWN:
			Global.cycle_weapon(1)
			get_tree().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if Global.is_driving:
		if Global.current_vehicle and is_instance_valid(Global.current_vehicle):
			global_transform.origin = Global.current_vehicle.global_transform.origin
		velocity = Vector3.ZERO
		return

	# Chrono-dilation delta compensation for player actions
	var real_delta := delta / Engine.time_scale if Engine.time_scale > 0.0 else delta

	if _fire_timer > 0.0:
		_fire_timer -= real_delta

	if _is_melee_swinging:
		_process_melee_animation(real_delta)

	# Chrono Dilation Stamina Drain
	if Global.chrono_dilation_active:
		if not Global.god_mode:
			current_stamina = max(0.0, current_stamina - Global.chrono_dilation_drain_rate * real_delta)
			if current_stamina <= 0.0:
				Global.set_chrono_dilation(false)

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
		_process_flight_movement(input_dir, is_trying_sprint, real_delta)
	else:
		_process_ground_movement(input_dir, is_moving, is_trying_sprint, real_delta)

	# 3. Sync Stamina & Health to Global
	if Global.god_mode or Global.infinite_speed:
		current_stamina = max_stamina
	Global.current_stamina = current_stamina
	Global.health = health

	# 4. Handle Combat Attacks based on Active Weapon
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED and not _is_melee_swinging:
		if (Input.is_action_pressed("Aim") or Input.is_action_pressed("Fire")) and _fire_timer <= 0.0:
			_execute_attack()

	# 5. Check Nearby Interactables (Vehicles & Chests)
	_update_nearby_interactables()

func _execute_attack() -> void:
	if camera_pivot:
		var cam_fwd := -camera_pivot.global_transform.basis.z
		cam_fwd.y = 0.0
		if cam_fwd.length_squared() > 0.001:
			cam_fwd = cam_fwd.normalized()
			rotation.y = atan2(-cam_fwd.x, -cam_fwd.z)

	match Global.active_weapon:
		Global.WEAPON_BLASTER:
			_shoot_projectile()
		Global.WEAPON_SWORD:
			_attack_sword()
		Global.WEAPON_AXE:
			_attack_axe()

func _attack_sword() -> void:
	var stamina_cost: float = float(Global.WEAPON_CONFIGS[Global.WEAPON_SWORD]["stamina_cost"])
	if not Global.god_mode and current_stamina < stamina_cost:
		Global.notify("Low Stamina for Sword Slash!")
		_fire_timer = 0.3
		return

	if not Global.god_mode:
		current_stamina = max(0.0, current_stamina - stamina_cost)
	time_since_last_sprint = 0.0

	_fire_timer = float(Global.WEAPON_CONFIGS[Global.WEAPON_SWORD]["cooldown"])
	_start_melee_swing(0.24, Vector3(0.0, -85.0, 35.0))

	# Slight forward step
	var fwd := -global_transform.basis.z.normalized()
	velocity += fwd * 4.5

	# Hit sweep
	var base_dmg: float = float(Global.WEAPON_CONFIGS[Global.WEAPON_SWORD]["damage"])
	_sweep_melee_targets(3.4, deg2rad(75.0), base_dmg * Global.damage_multiplier, 9.0)

func _attack_axe() -> void:
	var stamina_cost: float = float(Global.WEAPON_CONFIGS[Global.WEAPON_AXE]["stamina_cost"])
	if not Global.god_mode and current_stamina < stamina_cost:
		Global.notify("Low Stamina for Battleaxe Cleave!")
		_fire_timer = 0.4
		return

	if not Global.god_mode:
		current_stamina = max(0.0, current_stamina - stamina_cost)
	time_since_last_sprint = 0.0

	_fire_timer = float(Global.WEAPON_CONFIGS[Global.WEAPON_AXE]["cooldown"])
	_start_melee_swing(0.48, Vector3(90.0, 0.0, -10.0))

	# Heavy forward lunge
	var fwd := -global_transform.basis.z.normalized()
	velocity += fwd * 6.5

	# Heavy cleave sweep
	var base_dmg: float = float(Global.WEAPON_CONFIGS[Global.WEAPON_AXE]["damage"])
	_sweep_melee_targets(4.0, deg2rad(85.0), base_dmg * Global.damage_multiplier, 18.0)

func _start_melee_swing(duration: float, _target_rot: Vector3) -> void:
	_is_melee_swinging = true
	_melee_swing_duration = duration
	_melee_swing_timer = duration

func _process_melee_animation(delta: float) -> void:
	_melee_swing_timer -= delta
	var progress := 1.0 - clamp(_melee_swing_timer / _melee_swing_duration, 0.0, 1.0)

	if _weapon_pivot:
		# Swing out and return
		var swing_curve := sin(progress * PI)
		if Global.active_weapon == Global.WEAPON_SWORD:
			_weapon_pivot.rotation_degrees = Vector3(-15.0 * swing_curve, -60.0 * swing_curve, 35.0 * swing_curve)
		elif Global.active_weapon == Global.WEAPON_AXE:
			_weapon_pivot.rotation_degrees = Vector3(65.0 * swing_curve, -15.0 * swing_curve, -20.0 * swing_curve)

	if _melee_swing_timer <= 0.0:
		_is_melee_swinging = false
		if _weapon_pivot:
			_weapon_pivot.rotation_degrees = Vector3.ZERO

func _sweep_melee_targets(max_range: float, max_angle_rad: float, damage: float, knockback_impulse: float) -> void:
	var enemies := get_tree().get_nodes_in_group("enemy")
	var hit_count := 0
	var fwd := -global_transform.basis.z.normalized()
	if camera_pivot and camera_pivot.has_node("Camera"):
		fwd = -(camera_pivot.get_node("Camera") as Camera).global_transform.basis.z.normalized()

	for e in enemies:
		if e is Spatial and is_instance_valid(e):
			var to_enemy: Vector3 = e.global_transform.origin - global_transform.origin
			var dist := to_enemy.length()
			if dist <= max_range:
				var dir := to_enemy.normalized()
				var angle := acos(clamp(fwd.dot(dir), -1.0, 1.0))
				if angle <= max_angle_rad:
					if e.has_method("take_damage"):
						e.call("take_damage", damage, global_transform.origin)
						hit_count += 1
						if "velocity" in e:
							e.velocity += dir * knockback_impulse + Vector3.UP * (knockback_impulse * 0.4)

	if hit_count > 0:
		Global.notify("Slash impact! Hit %d targets for %d dmg!" % [hit_count, int(damage)])

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
		var fly_flat := Vector3(fly_dir.x, 0.0, fly_dir.z)
		if fly_flat.length_squared() > 0.01:
			var target_rot_y := atan2(-fly_flat.x, -fly_flat.z)
			rotation.y = lerp_angle(rotation.y, target_rot_y, min(1.0, 12.0 * delta))

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

	if is_moving and move_dir.length_squared() > 0.001 and not _is_melee_swinging:
		var target_rot_y := atan2(-move_dir.x, -move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_rot_y, min(1.0, 14.0 * delta))

	var is_sprinting := false
	if is_trying_sprint and is_moving and (current_stamina > 0.0 or Global.god_mode or Global.infinite_speed):
		is_sprinting = true
		if not Global.god_mode and not Global.infinite_speed:
			current_stamina = max(0.0, current_stamina - stamina_drain_rate * delta)
		time_since_last_sprint = 0.0
	else:
		time_since_last_sprint += delta
		if time_since_last_sprint >= stamina_regen_delay and not Global.chrono_dilation_active:
			current_stamina = min(max_stamina, current_stamina + stamina_regen_rate * delta)

	var base_spd := sprint_speed if is_sprinting else walk_speed
	var target_speed := base_spd * Global.speed_multiplier * (1.4 if Global.infinite_speed else 1.0)
	var target_velocity := move_dir * target_speed

	var accel := (acceleration * 2.5) if Global.infinite_speed else acceleration
	velocity.x = lerp(velocity.x, target_velocity.x, min(1.0, accel * delta))
	velocity.z = lerp(velocity.z, target_velocity.z, min(1.0, accel * delta))

	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_impulse * Global.jump_multiplier
			snap_vector = Vector3.ZERO
		elif velocity.y > 0.1:
			# External vertical impulse (launch pad, knockback, explosion)
			snap_vector = Vector3.ZERO
		else:
			velocity.y = -0.1
			snap_vector = -get_floor_normal()
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
	_nearby_vehicle = null

	# Check vehicles
	var vehicles := get_tree().get_nodes_in_group("vehicle")
	var best_veh_dist := 5.0
	for v in vehicles:
		if v is Spatial and is_instance_valid(v):
			var d := global_transform.origin.distance_to(v.global_transform.origin)
			if d <= best_veh_dist:
				best_veh_dist = d
				_nearby_vehicle = v

	# Check chests
	var chests := get_tree().get_nodes_in_group("chest")
	var best_dist := 4.5
	for c in chests:
		if c is Spatial and is_instance_valid(c):
			var d := global_transform.origin.distance_to(c.global_transform.origin)
			if d <= best_dist:
				best_dist = d
				_nearby_chest = c

	if _hud:
		if _nearby_vehicle:
			var v_name: String = _nearby_vehicle.get("vehicle_name") if "vehicle_name" in _nearby_vehicle else "Wasteland Cruiser"
			_hud.call("set_interaction_prompt", "[E] Drive %s" % v_name)
		elif _nearby_chest:
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
	Global.set_chrono_dilation(false)
	velocity = Vector3.ZERO
	global_transform = _spawn_transform
	Global.notify("You were defeated! Respawned at checkpoint.")