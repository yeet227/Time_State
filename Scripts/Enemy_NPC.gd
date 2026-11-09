extends KinematicBody

const ProjectileScript = preload("res://Scripts/Projectile.gd")
const PickupScript = preload("res://Scripts/Pickup.gd")
const GremlinModelScene = preload("res://Assets/Blender Assets/Enemies/Bouncing_Enemy_Gremlin.glb")
const DroneModelScene = preload("res://Assets/Blender Assets/Enemies/Floating_Bot.glb")

export var enemy_id: String = ""
export(String, "raider", "gremlin", "drone", "automaton") var enemy_type: String = "raider"
export var max_health: float = 100.0
export var move_speed: float = 6.5
export var wander_speed: float = 3.2
export var gravity: float = 24.0
export var stop_distance: float = 4.0

# --- Combat & Detection ---
export var detection_range: float = 24.0
export var lose_interest_range: float = 34.0
export var shoot_range: float = 22.0
export var shoot_cooldown: float = 1.6
export var projectile_damage: float = 12.0
export var projectile_speed: float = 26.0
export var melee_range: float = 2.4
export var melee_damage: float = 15.0
export var melee_cooldown: float = 1.2

# --- Wander Parameters ---
export var wander_radius: float = 10.0
export var wander_wait_time: float = 2.0

var current_health: float = 100.0
var velocity: Vector3 = Vector3.ZERO
var target_node: Spatial = null

var _home_position: Vector3 = Vector3.ZERO
var _wander_target: Vector3 = Vector3.ZERO
var _wander_timer: float = 0.0
var _is_wandering_moving: bool = false
var _shoot_timer: float = 0.8
var _melee_timer: float = 0.0
var _flash_timer: float = 0.0
var _gremlin_hop_timer: float = 0.0
var _drone_hover_time: float = 0.0
var _rng := RandomNumberGenerator.new()
var _base_material: SpatialMaterial = null
var _hp_bar_fill: MeshInstance = null
var _hp_bar_mat: SpatialMaterial = null
var _custom_visual: Spatial = null

func _ready() -> void:
	if not enemy_id.empty() and Global.defeated_enemies.has(enemy_id):
		queue_free()
		return

	add_to_group("enemy")
	_home_position = global_transform.origin
	_rng.randomize()
	_apply_enemy_archetype()
	current_health = max_health
	_pick_new_wander_target()

	_build_health_bar()

func _apply_enemy_archetype() -> void:
	match enemy_type:
		"gremlin":
			# Fast, aggressive melee swarmer
			max_health = 75.0
			move_speed = 9.5
			wander_speed = 4.2
			shoot_range = 0.0 # Pure melee
			melee_damage = 22.0
			melee_cooldown = 0.8
			detection_range = 28.0
			stop_distance = 1.2

			if has_node("Body"):
				($Body as Spatial).visible = false
			if has_node("Front_enemy"):
				($Front_enemy as Spatial).visible = false

			_custom_visual = GremlinModelScene.instance() as Spatial
			_custom_visual.scale = Vector3(0.85, 0.85, 0.85)
			add_child(_custom_visual)

		"drone":
			# Aerial floating sniper drone
			max_health = 85.0
			move_speed = 6.8
			wander_speed = 3.5
			gravity = 0.0 # Floats
			stop_distance = 10.0
			shoot_range = 32.0
			shoot_cooldown = 1.2
			projectile_damage = 18.0
			melee_damage = 8.0
			detection_range = 32.0

			if has_node("Body"):
				($Body as Spatial).visible = false
			if has_node("Front_enemy"):
				($Front_enemy as Spatial).visible = false

			_custom_visual = DroneModelScene.instance() as Spatial
			_custom_visual.scale = Vector3(0.45, 0.45, 0.45)
			add_child(_custom_visual)

		"automaton":
			# Heavy armored tanky scrapper bot
			max_health = 220.0
			move_speed = 4.2
			wander_speed = 2.4
			melee_damage = 32.0
			projectile_damage = 22.0
			shoot_cooldown = 2.0
			shoot_range = 25.0
			scale = Vector3(1.35, 1.35, 1.35)

			if has_node("Body") and $Body is MeshInstance:
				var body_mesh: MeshInstance = $Body
				var mat := body_mesh.get_surface_material(0)
				if mat is SpatialMaterial:
					_base_material = mat.duplicate() as SpatialMaterial
					_base_material.albedo_color = Color(0.45, 0.35, 0.3)
					_base_material.metallic = 0.8
					body_mesh.set_surface_material(0, _base_material)

		_: # "raider" default
			max_health = 100.0
			move_speed = 6.5
			if has_node("Body") and $Body is MeshInstance:
				var body_mesh: MeshInstance = $Body
				var mat := body_mesh.get_surface_material(0)
				if mat is SpatialMaterial:
					_base_material = mat.duplicate() as SpatialMaterial
					body_mesh.set_surface_material(0, _base_material)

func _build_health_bar() -> void:
	var bar_y := 2.2 if enemy_type == "automaton" else 1.75

	var bg_inst := MeshInstance.new()
	var bg_mesh := CubeMesh.new()
	bg_mesh.size = Vector3(1.24, 0.16, 0.04)
	var bg_mat := SpatialMaterial.new()
	bg_mat.flags_unshaded = true
	bg_mat.params_billboard_mode = SpatialMaterial.BILLBOARD_FIXED_Y
	bg_mat.albedo_color = Color(0.08, 0.08, 0.08, 1.0)
	bg_mesh.material = bg_mat
	bg_inst.mesh = bg_mesh
	bg_inst.translation = Vector3(0.0, bar_y, 0.0)
	add_child(bg_inst)

	_hp_bar_fill = MeshInstance.new()
	var fill_mesh := CubeMesh.new()
	fill_mesh.size = Vector3(1.18, 0.11, 0.06)
	_hp_bar_mat = SpatialMaterial.new()
	_hp_bar_mat.flags_unshaded = true
	_hp_bar_mat.params_billboard_mode = SpatialMaterial.BILLBOARD_FIXED_Y
	_hp_bar_mat.albedo_color = Color(0.2, 0.9, 0.3, 1.0)
	fill_mesh.material = _hp_bar_mat
	_hp_bar_fill.mesh = fill_mesh
	_hp_bar_fill.translation = Vector3(0.0, bar_y, 0.0)
	add_child(_hp_bar_fill)

func set_target(new_target: Spatial) -> void:
	target_node = new_target

func _on_Area_body_entered(body: Node) -> void:
	if body == self:
		return
	if body and (body.is_in_group("player") or body.name == "Player"):
		set_target(body as Spatial)

func _on_Area_body_exited(body: Node) -> void:
	if body == target_node:
		if global_transform.origin.distance_to(target_node.global_transform.origin) > lose_interest_range:
			target_node = null

func _physics_process(delta: float) -> void:
	# 1. Handle hit flash feedback
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0 and _base_material:
			_base_material.emission_enabled = false

	# 2. Apply gravity or aerial hover
	if enemy_type == "drone":
		_drone_hover_time += delta * 2.5
		var target_y := _home_position.y + 3.8 + sin(_drone_hover_time) * 0.4
		if target_node and is_instance_valid(target_node):
			target_y = target_node.global_transform.origin.y + 3.5 + sin(_drone_hover_time) * 0.4
		velocity.y = lerp(velocity.y, (target_y - global_transform.origin.y) * 3.0, min(1.0, 5.0 * delta))
	else:
		if not is_on_floor():
			velocity.y -= gravity * delta
		else:
			velocity.y = -0.1

	# 3. Cooldown timers
	if _shoot_timer > 0.0:
		_shoot_timer -= delta
	if _melee_timer > 0.0:
		_melee_timer -= delta

	# 4. Acquire or validate player target by proximity
	_update_target_acquisition()

	if target_node and is_instance_valid(target_node):
		_process_combat_and_chase(delta)
	else:
		_process_wander(delta)

	velocity = move_and_slide(velocity, Vector3.UP)

func _update_target_acquisition() -> void:
	if target_node and is_instance_valid(target_node):
		var dist := global_transform.origin.distance_to(target_node.global_transform.origin)
		if dist > lose_interest_range:
			target_node = null
		return

	var players := get_tree().get_nodes_in_group("player")
	if not players.empty():
		var p := players[0] as Spatial
		if p and is_instance_valid(p) and p.visible:
			if global_transform.origin.distance_to(p.global_transform.origin) <= detection_range:
				target_node = p

func _process_combat_and_chase(delta: float) -> void:
	var current_pos := global_transform.origin
	var target_pos := target_node.global_transform.origin
	var diff := target_pos - current_pos
	var flat_diff := Vector3(diff.x, 0.0, diff.z)
	var horizontal_dist := flat_diff.length()

	if horizontal_dist > 0.05:
		var dir := flat_diff.normalized()
		var target_angle := atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 8.0 * delta)

		if horizontal_dist > stop_distance:
			velocity.x = dir.x * move_speed
			velocity.z = dir.z * move_speed

			# Gremlin bouncing hop
			if enemy_type == "gremlin":
				_gremlin_hop_timer -= delta
				if _gremlin_hop_timer <= 0.0 and is_on_floor():
					velocity.y = 8.5
					_gremlin_hop_timer = _rng.randf_range(1.2, 2.0)
		else:
			velocity.x = lerp(velocity.x, 0.0, 10.0 * delta)
			velocity.z = lerp(velocity.z, 0.0, 10.0 * delta)

	# Melee Damage if close
	if horizontal_dist <= melee_range and _melee_timer <= 0.0:
		if target_node.has_method("take_damage"):
			target_node.call("take_damage", melee_damage, global_transform.origin)
			_melee_timer = melee_cooldown

	# Shoot Back if within shoot range
	var total_dist := diff.length()
	if shoot_range > 0.0 and total_dist <= shoot_range and _shoot_timer <= 0.0:
		_shoot_at_target(target_pos + Vector3(0.0, 0.8, 0.0))
		_shoot_timer = shoot_cooldown

func _shoot_at_target(aim_point: Vector3) -> void:
	var muzzle_pos := global_transform.origin + Vector3(0.0, 0.65, 0.0)
	if has_node("Front_enemy") and ($Front_enemy as Spatial).visible:
		muzzle_pos = ($Front_enemy as Spatial).global_transform.origin

	var shoot_dir := (aim_point - muzzle_pos).normalized()
	if shoot_dir.length_squared() < 0.01:
		shoot_dir = global_transform.basis.z.normalized()

	var proj := Area.new()
	proj.set_script(ProjectileScript)
	proj.shooter = self
	proj.is_enemy_projectile = true
	proj.damage = projectile_damage
	proj.speed = projectile_speed
	proj.direction = shoot_dir

	var parent_scene := get_tree().current_scene if get_tree().current_scene else get_parent()
	parent_scene.add_child(proj)
	proj.global_transform.origin = muzzle_pos + shoot_dir * 0.6

func _process_wander(delta: float) -> void:
	_wander_timer -= delta
	if _is_wandering_moving:
		var diff := _wander_target - global_transform.origin
		diff.y = 0.0
		if diff.length() <= 0.8 or _wander_timer <= 0.0:
			_is_wandering_moving = false
			_wander_timer = _rng.randf_range(1.2, wander_wait_time)
		else:
			var dir := diff.normalized()
			velocity.x = dir.x * wander_speed
			velocity.z = dir.z * wander_speed
			var target_angle := atan2(dir.x, dir.z)
			rotation.y = lerp_angle(rotation.y, target_angle, 5.0 * delta)
	else:
		velocity.x = lerp(velocity.x, 0.0, 8.0 * delta)
		velocity.z = lerp(velocity.z, 0.0, 8.0 * delta)
		if _wander_timer <= 0.0:
			_pick_new_wander_target()

func _pick_new_wander_target() -> void:
	var angle := _rng.randf_range(0.0, TAU)
	var dist := _rng.randf_range(2.5, wander_radius)
	_wander_target = _home_position + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
	_is_wandering_moving = true
	_wander_timer = _rng.randf_range(3.0, 6.0)

func take_damage(amount: float, source_pos: Vector3 = Vector3.ZERO) -> void:
	current_health = max(0.0, current_health - amount)
	_flash_timer = 0.15

	if _base_material:
		_base_material.emission_enabled = true
		_base_material.emission = Color(1.0, 1.0, 1.0)
		_base_material.emission_energy = 1.2

	if source_pos != Vector3.ZERO:
		var push_dir := (global_transform.origin - source_pos)
		push_dir.y = 0.0
		if push_dir.length_squared() > 0.01:
			velocity += push_dir.normalized() * 12.0 + Vector3.UP * 5.0

	if _hp_bar_fill and max_health > 0.0:
		var ratio := clamp(current_health / max_health, 0.0, 1.0)
		_hp_bar_fill.scale.x = max(0.001, ratio)
		if _hp_bar_mat:
			_hp_bar_mat.albedo_color = Color(1.0 - ratio * 0.8, ratio * 0.9, 0.2, 1.0)

	# Alert enemy to target
	if target_node == null:
		var players := get_tree().get_nodes_in_group("player")
		if not players.empty():
			target_node = players[0] as Spatial

	if current_health <= 0.0:
		_die()

func _die() -> void:
	if not enemy_id.empty():
		Global.defeated_enemies[enemy_id] = true

	# Spawn a pickup drop on defeat
	var drop := Area.new()
	drop.set_script(PickupScript)
	var loot_table := ["medkit", "ammo_pack", "stamina_tonic", "time_crystal"]
	if enemy_type == "gremlin":
		loot_table = ["stamina_tonic", "time_crystal", "medkit"]
	elif enemy_type == "drone":
		loot_table = ["ammo_pack", "speed_core", "time_crystal"]
	elif enemy_type == "automaton":
		loot_table = ["time_crystal", "speed_core", "ammo_pack"]

	drop.item_id = loot_table[_rng.randi() % loot_table.size()]
	drop.count = 1
	drop.translation = global_transform.origin + Vector3(0.0, 0.5, 0.0)
	var parent_scene := get_tree().current_scene if get_tree().current_scene else get_parent()
	parent_scene.add_child(drop)

	Global.notify("%s defeated! Dropped %s" % [enemy_type.capitalize(), Global.ITEM_DB[drop.item_id]["name"]])
	queue_free()