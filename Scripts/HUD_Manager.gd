extends CanvasLayer

var player_node: Spatial = null
var active_chest_id: String = ""
var active_chest_title: String = "Chest Storage"

# --- HUD Elements ---
var _health_bar: ProgressBar
var _health_label: Label
var _stamina_bar: ProgressBar
var _stamina_label: Label
var _ammo_label: Label
var _status_label: Label
var _prompt_label: Label
var _toast_label: Label
var _toast_timer: float = 0.0
var _damage_flash: ColorRect
var _damage_flash_alpha: float = 0.0

# --- Modal Panels ---
var _backdrop: ColorRect
var _pause_panel: Panel
var _inventory_panel: Panel
var _settings_panel: Panel
var _cheat_panel: Panel

# --- Dynamic Lists & Controls ---
var _inv_list_vbox: VBoxContainer
var _chest_section: VBoxContainer
var _chest_title_label: Label
var _chest_list_vbox: VBoxContainer

# --- Cheat Controls ---
var _chk_god: CheckBox
var _chk_inf_speed: CheckBox
var _chk_flight: CheckBox
var _sld_speed: HSlider
var _lbl_speed_val: Label
var _sld_flight: HSlider
var _lbl_flight_val: Label
var _sld_jump: HSlider
var _lbl_jump_val: Label
var _sld_damage: HSlider
var _lbl_damage_val: Label

# --- Settings Controls ---
var _chk_fps: CheckBox
var _chk_vsync: CheckBox
var _chk_fullscreen: CheckBox
var _sld_sens: HSlider
var _lbl_sens_val: Label
var _sld_fov: HSlider
var _lbl_fov_val: Label
var _sld_vol: HSlider
var _lbl_vol_val: Label

func _ready() -> void:
	layer = 10
	pause_mode = Node.PAUSE_MODE_PROCESS
	add_to_group("hud")

	_build_hud()
	_build_modals()

	var _e1 := Global.connect("stats_changed", self, "refresh_hud")
	var _e2 := Global.connect("inventory_changed", self, "refresh_inventory_ui")
	var _e3 := Global.connect("chest_changed", self, "_on_chest_changed")
	var _e4 := Global.connect("cheats_changed", self, "_sync_cheat_controls")
	var _e5 := Global.connect("settings_changed", self, "_sync_settings_controls")
	var _e6 := Global.connect("notification_requested", self, "show_toast")

	refresh_hud()
	_sync_cheat_controls()
	_sync_settings_controls()

func _build_hud() -> void:
	var root := Control.new()
	root.name = "HUDRoot"
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Damage Flash Overlay
	_damage_flash = ColorRect.new()
	_damage_flash.anchor_right = 1.0
	_damage_flash.anchor_bottom = 1.0
	_damage_flash.color = Color(0.85, 0.05, 0.05, 0.0)
	_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_damage_flash)

	# Top-Right Status Box (Health, Stamina, Ammo)
	var stats_bg := ColorRect.new()
	stats_bg.anchor_left = 1.0
	stats_bg.anchor_right = 1.0
	stats_bg.margin_left = -340.0
	stats_bg.margin_top = 16.0
	stats_bg.margin_right = -16.0
	stats_bg.margin_bottom = 148.0
	stats_bg.color = Color(0.06, 0.07, 0.1, 0.78)
	stats_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(stats_bg)

	_health_bar = ProgressBar.new()
	_health_bar.margin_left = 14.0
	_health_bar.margin_top = 12.0
	_health_bar.margin_right = 310.0
	_health_bar.margin_bottom = 38.0
	_health_bar.percent_visible = false
	_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_bg.add_child(_health_bar)

	_health_label = Label.new()
	_health_label.anchor_right = 1.0
	_health_label.anchor_bottom = 1.0
	_health_label.align = Label.ALIGN_CENTER
	_health_label.valign = Label.VALIGN_CENTER
	_health_label.text = "HP: 100 / 100"
	_health_bar.add_child(_health_label)

	_stamina_bar = ProgressBar.new()
	_stamina_bar.margin_left = 14.0
	_stamina_bar.margin_top = 48.0
	_stamina_bar.margin_right = 310.0
	_stamina_bar.margin_bottom = 74.0
	_stamina_bar.percent_visible = false
	_stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_bg.add_child(_stamina_bar)

	_stamina_label = Label.new()
	_stamina_label.anchor_right = 1.0
	_stamina_label.anchor_bottom = 1.0
	_stamina_label.align = Label.ALIGN_CENTER
	_stamina_label.valign = Label.VALIGN_CENTER
	_stamina_label.text = "STM: 100 / 100"
	_stamina_bar.add_child(_stamina_label)

	_ammo_label = Label.new()
	_ammo_label.margin_left = 14.0
	_ammo_label.margin_top = 82.0
	_ammo_label.margin_right = 310.0
	_ammo_label.margin_bottom = 104.0
	_ammo_label.text = "ENERGY AMMO: 30 / 150"
	stats_bg.add_child(_ammo_label)

	_status_label = Label.new()
	_status_label.margin_left = 14.0
	_status_label.margin_top = 106.0
	_status_label.margin_right = 310.0
	_status_label.margin_bottom = 126.0
	_status_label.add_color_override("font_color", Color(0.4, 0.9, 1.0))
	_status_label.text = "Spd: 1.0x | Fly: OFF | Dmg: 1.0x"
	stats_bg.add_child(_status_label)

	# Center Crosshair
	var crosshair := Label.new()
	crosshair.anchor_left = 0.5
	crosshair.anchor_top = 0.5
	crosshair.anchor_right = 0.5
	crosshair.anchor_bottom = 0.5
	crosshair.margin_left = -20.0
	crosshair.margin_top = -20.0
	crosshair.margin_right = 20.0
	crosshair.margin_bottom = 20.0
	crosshair.align = Label.ALIGN_CENTER
	crosshair.valign = Label.VALIGN_CENTER
	crosshair.text = "+"
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crosshair)

	# Interaction Prompt
	_prompt_label = Label.new()
	_prompt_label.anchor_left = 0.5
	_prompt_label.anchor_top = 0.65
	_prompt_label.anchor_right = 0.5
	_prompt_label.anchor_bottom = 0.65
	_prompt_label.margin_left = -250.0
	_prompt_label.margin_right = 250.0
	_prompt_label.margin_bottom = 36.0
	_prompt_label.align = Label.ALIGN_CENTER
	_prompt_label.valign = Label.VALIGN_CENTER
	_prompt_label.add_color_override("font_color", Color(1.0, 0.95, 0.35))
	_prompt_label.add_color_override("font_color_shadow", Color(0, 0, 0, 1))
	_prompt_label.text = ""
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_prompt_label)

	# Toast Notification
	_toast_label = Label.new()
	_toast_label.anchor_left = 0.5
	_toast_label.anchor_top = 0.15
	_toast_label.anchor_right = 0.5
	_toast_label.anchor_bottom = 0.15
	_toast_label.margin_left = -300.0
	_toast_label.margin_right = 300.0
	_toast_label.margin_bottom = 40.0
	_toast_label.align = Label.ALIGN_CENTER
	_toast_label.valign = Label.VALIGN_CENTER
	_toast_label.add_color_override("font_color", Color(0.3, 1.0, 0.5))
	_toast_label.add_color_override("font_color_shadow", Color(0, 0, 0, 1))
	_toast_label.text = ""
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toast_label)

	# Bottom Keybind Hints
	var hints_bg := ColorRect.new()
	hints_bg.anchor_top = 1.0
	hints_bg.anchor_right = 1.0
	hints_bg.anchor_bottom = 1.0
	hints_bg.margin_top = -34.0
	hints_bg.color = Color(0.04, 0.05, 0.08, 0.72)
	hints_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hints_bg)

	var hints_lbl := Label.new()
	hints_lbl.anchor_right = 1.0
	hints_lbl.anchor_bottom = 1.0
	hints_lbl.align = Label.ALIGN_CENTER
	hints_lbl.valign = Label.VALIGN_CENTER
	hints_lbl.text = "[LMB/RMB] Shoot  |  [E] Interact/Chest  |  [I/Tab] Inventory  |  [F1] Cheat Menu  |  [V] Flight  |  [F5] Quick Save  |  [F9] Quick Load  |  [ESC] Pause"
	hints_bg.add_child(hints_lbl)

func _build_modals() -> void:
	_backdrop = ColorRect.new()
	_backdrop.anchor_right = 1.0
	_backdrop.anchor_bottom = 1.0
	_backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	_backdrop.visible = false
	add_child(_backdrop)

	_build_pause_panel()
	_build_inventory_panel()
	_build_settings_panel()
	_build_cheat_panel()

func _build_pause_panel() -> void:
	_pause_panel = Panel.new()
	_pause_panel.anchor_left = 0.5
	_pause_panel.anchor_top = 0.5
	_pause_panel.anchor_right = 0.5
	_pause_panel.anchor_bottom = 0.5
	_pause_panel.margin_left = -200.0
	_pause_panel.margin_top = -230.0
	_pause_panel.margin_right = 200.0
	_pause_panel.margin_bottom = 230.0
	_pause_panel.visible = false
	add_child(_pause_panel)

	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.margin_left = 24.0
	vbox.margin_top = 20.0
	vbox.margin_right = -24.0
	vbox.margin_bottom = -20.0
	vbox.add_constant_override("separation", 10)
	_pause_panel.add_child(vbox)

	var title := Label.new()
	title.text = "=== GAME PAUSED ==="
	title.align = Label.ALIGN_CENTER
	vbox.add_child(title)

	_add_btn(vbox, "Resume Game (ESC)", "_on_resume_pressed")
	_add_btn(vbox, "Inventory & Storage (I)", "_on_open_inventory_pressed")
	_add_btn(vbox, "Cheat Menu & Multipliers (F1)", "_on_open_cheats_pressed")
	_add_btn(vbox, "Settings", "_on_open_settings_pressed")
	_add_btn(vbox, "Save Game (F5)", "_on_save_game_pressed")
	_add_btn(vbox, "Load Game (F9)", "_on_load_game_pressed")
	_add_btn(vbox, "Return to Main Menu", "_on_main_menu_pressed")
	_add_btn(vbox, "Quit to Desktop", "_on_quit_pressed")

func _build_inventory_panel() -> void:
	_inventory_panel = Panel.new()
	_inventory_panel.anchor_left = 0.5
	_inventory_panel.anchor_top = 0.5
	_inventory_panel.anchor_right = 0.5
	_inventory_panel.anchor_bottom = 0.5
	_inventory_panel.margin_left = -420.0
	_inventory_panel.margin_top = -250.0
	_inventory_panel.margin_right = 420.0
	_inventory_panel.margin_bottom = 250.0
	_inventory_panel.visible = false
	add_child(_inventory_panel)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.anchor_right = 1.0
	outer_vbox.anchor_bottom = 1.0
	outer_vbox.margin_left = 20.0
	outer_vbox.margin_top = 16.0
	outer_vbox.margin_right = -20.0
	outer_vbox.margin_bottom = -16.0
	outer_vbox.add_constant_override("separation", 10)
	_inventory_panel.add_child(outer_vbox)

	var header := Label.new()
	header.text = "=== INVENTORY & CHEST STORAGE ==="
	header.align = Label.ALIGN_CENTER
	outer_vbox.add_child(header)

	var hbox := HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_constant_override("separation", 20)
	outer_vbox.add_child(hbox)

	# Left Column: Player Inventory
	var inv_col := VBoxContainer.new()
	inv_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(inv_col)

	var inv_title := Label.new()
	inv_title.text = "Player Backpack"
	inv_col.add_child(inv_title)

	var inv_scroll := ScrollContainer.new()
	inv_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inv_col.add_child(inv_scroll)

	_inv_list_vbox = VBoxContainer.new()
	_inv_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inv_list_vbox.add_constant_override("separation", 6)
	inv_scroll.add_child(_inv_list_vbox)

	# Right Column: Chest Storage
	_chest_section = VBoxContainer.new()
	_chest_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chest_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(_chest_section)

	_chest_title_label = Label.new()
	_chest_title_label.text = "Chest Storage"
	_chest_section.add_child(_chest_title_label)

	var chest_scroll := ScrollContainer.new()
	chest_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chest_section.add_child(chest_scroll)

	_chest_list_vbox = VBoxContainer.new()
	_chest_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chest_list_vbox.add_constant_override("separation", 6)
	chest_scroll.add_child(_chest_list_vbox)

	_add_btn(_chest_section, "Take All From Chest", "_on_take_all_chest_pressed")

	var bottom_hbox := HBoxContainer.new()
	bottom_hbox.alignment = BoxContainer.ALIGN_CENTER
	bottom_hbox.add_constant_override("separation", 16)
	outer_vbox.add_child(bottom_hbox)

	_add_btn(bottom_hbox, "Close (ESC / I)", "_on_close_subpanel_pressed")

func _build_settings_panel() -> void:
	_settings_panel = Panel.new()
	_settings_panel.anchor_left = 0.5
	_settings_panel.anchor_top = 0.5
	_settings_panel.anchor_right = 0.5
	_settings_panel.anchor_bottom = 0.5
	_settings_panel.margin_left = -260.0
	_settings_panel.margin_top = -230.0
	_settings_panel.margin_right = 260.0
	_settings_panel.margin_bottom = 230.0
	_settings_panel.visible = false
	add_child(_settings_panel)

	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.margin_left = 24.0
	vbox.margin_top = 18.0
	vbox.margin_right = -24.0
	vbox.margin_bottom = -18.0
	vbox.add_constant_override("separation", 10)
	_settings_panel.add_child(vbox)

	var title := Label.new()
	title.text = "=== GAME SETTINGS ==="
	title.align = Label.ALIGN_CENTER
	vbox.add_child(title)

	_chk_fps = CheckBox.new()
	_chk_fps.text = "Show FPS Counter"
	var _c1 := _chk_fps.connect("toggled", self, "_on_settings_modified")
	vbox.add_child(_chk_fps)

	_chk_vsync = CheckBox.new()
	_chk_vsync.text = "Enable VSync"
	var _c2 := _chk_vsync.connect("toggled", self, "_on_settings_modified")
	vbox.add_child(_chk_vsync)

	_chk_fullscreen = CheckBox.new()
	_chk_fullscreen.text = "Fullscreen Mode"
	var _c3 := _chk_fullscreen.connect("toggled", self, "_on_settings_modified")
	vbox.add_child(_chk_fullscreen)

	var sens_row := _create_slider_row(vbox, "Mouse Sensitivity:", 0.02, 0.40, 0.01, Global.mouse_sensitivity, "_on_settings_slider_changed")
	_sld_sens = sens_row[0]
	_lbl_sens_val = sens_row[1]

	var fov_row := _create_slider_row(vbox, "Camera FOV:", 60.0, 115.0, 1.0, Global.fov, "_on_settings_slider_changed")
	_sld_fov = fov_row[0]
	_lbl_fov_val = fov_row[1]

	var vol_row := _create_slider_row(vbox, "Master Volume:", 0.0, 1.0, 0.05, Global.master_volume, "_on_settings_slider_changed")
	_sld_vol = vol_row[0]
	_lbl_vol_val = vol_row[1]

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGN_CENTER
	btn_row.add_constant_override("separation", 16)
	vbox.add_child(btn_row)

	_add_btn(btn_row, "Save & Apply", "_on_save_settings_pressed")
	_add_btn(btn_row, "Back", "_on_back_to_pause_pressed")

func _build_cheat_panel() -> void:
	_cheat_panel = Panel.new()
	_cheat_panel.anchor_left = 0.5
	_cheat_panel.anchor_top = 0.5
	_cheat_panel.anchor_right = 0.5
	_cheat_panel.anchor_bottom = 0.5
	_cheat_panel.margin_left = -290.0
	_cheat_panel.margin_top = -255.0
	_cheat_panel.margin_right = 290.0
	_cheat_panel.margin_bottom = 255.0
	_cheat_panel.visible = false
	add_child(_cheat_panel)

	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.margin_left = 22.0
	vbox.margin_top = 16.0
	vbox.margin_right = -22.0
	vbox.margin_bottom = -16.0
	vbox.add_constant_override("separation", 8)
	_cheat_panel.add_child(vbox)

	var title := Label.new()
	title.text = "=== CHEAT MENU & MULTIPLIERS ==="
	title.align = Label.ALIGN_CENTER
	vbox.add_child(title)

	_chk_god = CheckBox.new()
	_chk_god.text = "God Mode (Invulnerable + Infinite Stamina & Ammo)"
	var _g1 := _chk_god.connect("toggled", self, "_on_cheat_toggled")
	vbox.add_child(_chk_god)

	_chk_inf_speed = CheckBox.new()
	_chk_inf_speed.text = "Infinite Speed (Zero Stamina Drain + Instant Accel)"
	var _g2 := _chk_inf_speed.connect("toggled", self, "_on_cheat_toggled")
	vbox.add_child(_chk_inf_speed)

	_chk_flight = CheckBox.new()
	_chk_flight.text = "Flight Mode [V] (Space = Ascend, Ctrl/C = Descend)"
	var _g3 := _chk_flight.connect("toggled", self, "_on_cheat_toggled")
	vbox.add_child(_chk_flight)

	var spd_row := _create_slider_row(vbox, "Speed Multiplier:", 0.5, 10.0, 0.25, Global.speed_multiplier, "_on_cheat_slider_changed")
	_sld_speed = spd_row[0]
	_lbl_speed_val = spd_row[1]

	var fly_row := _create_slider_row(vbox, "Flight Multiplier:", 0.5, 10.0, 0.25, Global.flight_multiplier, "_on_cheat_slider_changed")
	_sld_flight = fly_row[0]
	_lbl_flight_val = fly_row[1]

	var jmp_row := _create_slider_row(vbox, "Jump Multiplier:", 0.5, 5.0, 0.25, Global.jump_multiplier, "_on_cheat_slider_changed")
	_sld_jump = jmp_row[0]
	_lbl_jump_val = jmp_row[1]

	var dmg_row := _create_slider_row(vbox, "Damage Multiplier:", 0.5, 10.0, 0.25, Global.damage_multiplier, "_on_cheat_slider_changed")
	_sld_damage = dmg_row[0]
	_lbl_damage_val = dmg_row[1]

	var actions_row := HBoxContainer.new()
	actions_row.alignment = BoxContainer.ALIGN_CENTER
	actions_row.add_constant_override("separation", 8)
	vbox.add_child(actions_row)

	_add_btn(actions_row, "Full Heal", "_on_cheat_heal_pressed")
	_add_btn(actions_row, "+50 Ammo", "_on_cheat_ammo_pressed")
	_add_btn(actions_row, "Give All Loot", "_on_cheat_loot_pressed")
	_add_btn(actions_row, "Reset 1.0x", "_on_cheat_reset_pressed")

	var close_row := HBoxContainer.new()
	close_row.alignment = BoxContainer.ALIGN_CENTER
	vbox.add_child(close_row)
	_add_btn(close_row, "Close Cheat Menu (F1 / ESC)", "_on_close_subpanel_pressed")

func _create_slider_row(parent: Node, label_text: String, min_v: float, max_v: float, step_v: float, initial_v: float, callback: String) -> Array:
	var row := HBoxContainer.new()
	row.add_constant_override("separation", 10)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.rect_min_size = Vector2(150.0, 0.0)
	row.add_child(lbl)

	var sld := HSlider.new()
	sld.min_value = min_v
	sld.max_value = max_v
	sld.step = step_v
	sld.value = initial_v
	sld.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _err := sld.connect("value_changed", self, callback)
	row.add_child(sld)

	var val_lbl := Label.new()
	val_lbl.rect_min_size = Vector2(65.0, 0.0)
	val_lbl.align = Label.ALIGN_RIGHT
	val_lbl.text = "%.2f" % initial_v
	row.add_child(val_lbl)

	return [sld, val_lbl]

func _add_btn(parent: Node, text_str: String, callback: String) -> void:
	var btn := Button.new()
	btn.text = text_str
	btn.rect_min_size = Vector2(110.0, 32.0)
	var _err := btn.connect("pressed", self, callback)
	parent.add_child(btn)

func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			_toast_label.text = ""

	if _damage_flash_alpha > 0.0:
		_damage_flash_alpha = max(0.0, _damage_flash_alpha - delta * 1.8)
		_damage_flash.color.a = _damage_flash_alpha

	refresh_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.scancode:
			KEY_ESCAPE:
				if is_any_modal_open():
					close_all_modals()
				else:
					open_pause_menu()
				get_tree().set_input_as_handled()
			KEY_I, KEY_TAB:
				if _inventory_panel.visible:
					close_all_modals()
				else:
					open_inventory("")
				get_tree().set_input_as_handled()
			KEY_F1:
				if _cheat_panel.visible:
					close_all_modals()
				else:
					open_cheat_menu()
				get_tree().set_input_as_handled()
			KEY_V:
				if not is_any_modal_open():
					Global.flight_enabled = not Global.flight_enabled
					_sync_cheat_controls()
					Global.notify("Flight Mode: %s" % ("ON" if Global.flight_enabled else "OFF"))
					get_tree().set_input_as_handled()
			KEY_F5:
				var _s := Global.save_game(player_node)
				get_tree().set_input_as_handled()
			KEY_F9:
				var _l := Global.load_game()
				get_tree().set_input_as_handled()

func is_any_modal_open() -> bool:
	return _pause_panel.visible or _inventory_panel.visible or _settings_panel.visible or _cheat_panel.visible

func close_all_modals() -> void:
	_backdrop.visible = false
	_pause_panel.visible = false
	_inventory_panel.visible = false
	_settings_panel.visible = false
	_cheat_panel.visible = false
	active_chest_id = ""
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func open_pause_menu() -> void:
	_hide_panels_only()
	_backdrop.visible = true
	_pause_panel.visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func open_inventory(chest_id: String = "", chest_title: String = "Supply Chest") -> void:
	_hide_panels_only()
	active_chest_id = chest_id
	active_chest_title = chest_title
	_backdrop.visible = true
	_inventory_panel.visible = true
	refresh_inventory_ui()
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func open_settings_menu() -> void:
	_hide_panels_only()
	_sync_settings_controls()
	_backdrop.visible = true
	_settings_panel.visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func open_cheat_menu() -> void:
	_hide_panels_only()
	_sync_cheat_controls()
	_backdrop.visible = true
	_cheat_panel.visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _hide_panels_only() -> void:
	_pause_panel.visible = false
	_inventory_panel.visible = false
	_settings_panel.visible = false
	_cheat_panel.visible = false

func refresh_hud() -> void:
	if _health_bar == null:
		return
	_health_bar.max_value = Global.max_health
	_health_bar.value = Global.health
	_health_label.text = "HP: %d / %d%s" % [int(Global.health), int(Global.max_health), " [GOD]" if Global.god_mode else ""]

	_stamina_bar.max_value = Global.max_stamina
	_stamina_bar.value = Global.current_stamina
	_stamina_label.text = "STM: %d / %d" % [int(Global.current_stamina), int(Global.max_stamina)]

	_ammo_label.text = "ENERGY AMMO: %s" % ("INF" if Global.god_mode else "%d / %d" % [Global.ammo, Global.max_ammo])

	var flags := []
	if Global.god_mode:
		flags.append("GOD")
	if Global.infinite_speed:
		flags.append("INF-SPD")
	if Global.flight_enabled:
		flags.append("FLY(%.1fx)" % Global.flight_multiplier)
	var flag_str := ("[" + PoolStringArray(flags).join(", ") + "] ") if not flags.empty() else ""
	_status_label.text = "%sSpd: %.2fx | Jmp: %.2fx | Dmg: %.2fx" % [
		flag_str,
		Global.speed_multiplier,
		Global.jump_multiplier,
		Global.damage_multiplier
	]

func set_interaction_prompt(text_str: String) -> void:
	if _prompt_label:
		_prompt_label.text = text_str

func show_toast(message: String) -> void:
	if _toast_label:
		_toast_label.text = message
		_toast_timer = 3.0

func trigger_damage_flash() -> void:
	_damage_flash_alpha = 0.45
	if _damage_flash:
		_damage_flash.color.a = _damage_flash_alpha

func refresh_inventory_ui() -> void:
	if _inv_list_vbox == null:
		return
	for c in _inv_list_vbox.get_children():
		c.queue_free()
	for c in _chest_list_vbox.get_children():
		c.queue_free()

	if Global.inventory.empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "(Backpack is empty)"
		_inv_list_vbox.add_child(empty_lbl)
	else:
		for i in range(Global.inventory.size()):
			var item: Dictionary = Global.inventory[i]
			var row := HBoxContainer.new()
			row.add_constant_override("separation", 8)
			_inv_list_vbox.add_child(row)

			var lbl := Label.new()
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lbl.text = "%s (x%d) - %s" % [item["name"], int(item["count"]), item.get("description", "")]
			row.add_child(lbl)

			var use_btn := Button.new()
			use_btn.text = "Use"
			var _u := use_btn.connect("pressed", self, "_on_use_item_pressed", [i])
			row.add_child(use_btn)

			if not active_chest_id.empty():
				var store_btn := Button.new()
				store_btn.text = "Store ->"
				var _s := store_btn.connect("pressed", self, "_on_store_item_pressed", [i])
				row.add_child(store_btn)

	_chest_section.visible = not active_chest_id.empty()
	if not active_chest_id.empty():
		_chest_title_label.text = "%s Storage" % active_chest_title
		var chest_items := Global.get_chest_items(active_chest_id)
		if chest_items.empty():
			var empty_c := Label.new()
			empty_c.text = "(Chest is empty)"
			_chest_list_vbox.add_child(empty_c)
		else:
			for j in range(chest_items.size()):
				var c_item: Dictionary = chest_items[j]
				var crow := HBoxContainer.new()
				crow.add_constant_override("separation", 8)
				_chest_list_vbox.add_child(crow)

				var take_btn := Button.new()
				take_btn.text = "<- Take"
				var _t := take_btn.connect("pressed", self, "_on_take_item_pressed", [j])
				crow.add_child(take_btn)

				var clbl := Label.new()
				clbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				clbl.text = "%s (x%d)" % [c_item["name"], int(c_item["count"])]
				crow.add_child(clbl)

func _on_chest_changed(_cid: String) -> void:
	refresh_inventory_ui()

func _on_use_item_pressed(index: int) -> void:
	var _used := Global.use_item_at(index, player_node)
	refresh_inventory_ui()

func _on_store_item_pressed(index: int) -> void:
	if not active_chest_id.empty():
		Global.transfer_to_chest(active_chest_id, index, 1)

func _on_take_item_pressed(chest_index: int) -> void:
	if not active_chest_id.empty():
		Global.transfer_from_chest(active_chest_id, chest_index, 1)

func _on_take_all_chest_pressed() -> void:
	if not active_chest_id.empty():
		Global.take_all_from_chest(active_chest_id)

# --- Button Callbacks ---
func _on_resume_pressed() -> void:
	close_all_modals()

func _on_open_inventory_pressed() -> void:
	open_inventory("")

func _on_open_cheats_pressed() -> void:
	open_cheat_menu()

func _on_open_settings_pressed() -> void:
	open_settings_menu()

func _on_save_game_pressed() -> void:
	var _ok := Global.save_game(player_node)

func _on_load_game_pressed() -> void:
	var _ok := Global.load_game()

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var _err := get_tree().change_scene("res://Scenes/Main Menu.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_close_subpanel_pressed() -> void:
	close_all_modals()

func _on_back_to_pause_pressed() -> void:
	open_pause_menu()

# --- Cheat Handlers ---
func _sync_cheat_controls() -> void:
	if _chk_god == null:
		return
	_chk_god.pressed = Global.god_mode
	_chk_inf_speed.pressed = Global.infinite_speed
	_chk_flight.pressed = Global.flight_enabled
	_sld_speed.value = Global.speed_multiplier
	_lbl_speed_val.text = "%.2fx" % Global.speed_multiplier
	_sld_flight.value = Global.flight_multiplier
	_lbl_flight_val.text = "%.2fx" % Global.flight_multiplier
	_sld_jump.value = Global.jump_multiplier
	_lbl_jump_val.text = "%.2fx" % Global.jump_multiplier
	_sld_damage.value = Global.damage_multiplier
	_lbl_damage_val.text = "%.2fx" % Global.damage_multiplier

func _on_cheat_toggled(_pressed: bool) -> void:
	Global.god_mode = _chk_god.pressed
	Global.infinite_speed = _chk_inf_speed.pressed
	Global.flight_enabled = _chk_flight.pressed
	if Global.god_mode:
		Global.health = Global.max_health
		Global.current_stamina = Global.max_stamina
	refresh_hud()

func _on_cheat_slider_changed(_val: float) -> void:
	Global.speed_multiplier = _sld_speed.value
	_lbl_speed_val.text = "%.2fx" % Global.speed_multiplier
	Global.flight_multiplier = _sld_flight.value
	_lbl_flight_val.text = "%.2fx" % Global.flight_multiplier
	Global.jump_multiplier = _sld_jump.value
	_lbl_jump_val.text = "%.2fx" % Global.jump_multiplier
	Global.damage_multiplier = _sld_damage.value
	_lbl_damage_val.text = "%.2fx" % Global.damage_multiplier
	refresh_hud()

func _on_cheat_heal_pressed() -> void:
	Global.health = Global.max_health
	Global.current_stamina = Global.max_stamina
	if player_node:
		if "health" in player_node:
			player_node.health = Global.health
		if "current_stamina" in player_node:
			player_node.current_stamina = Global.current_stamina
	Global.notify("Restored Full Health & Stamina!")

func _on_cheat_ammo_pressed() -> void:
	Global.ammo = int(min(Global.max_ammo, Global.ammo + 50))
	Global.notify("Added +50 Energy Ammo!")

func _on_cheat_loot_pressed() -> void:
	Global.add_item("medkit", 3)
	Global.add_item("stamina_tonic", 3)
	Global.add_item("ammo_pack", 3)
	Global.add_item("time_crystal", 2)
	Global.add_item("speed_core", 2)

func _on_cheat_reset_pressed() -> void:
	Global.speed_multiplier = 1.0
	Global.flight_multiplier = 1.0
	Global.jump_multiplier = 1.0
	Global.damage_multiplier = 1.0
	_sync_cheat_controls()
	Global.notify("Multipliers reset to 1.0x")

# --- Settings Handlers ---
func _sync_settings_controls() -> void:
	if _chk_fps == null:
		return
	_chk_fps.pressed = Global.ShowFPS
	_chk_vsync.pressed = Global.vsync_enabled
	_chk_fullscreen.pressed = Global.fullscreen_enabled
	_sld_sens.value = Global.mouse_sensitivity
	_lbl_sens_val.text = "%.2f" % Global.mouse_sensitivity
	_sld_fov.value = Global.fov
	_lbl_fov_val.text = "%d" % int(Global.fov)
	_sld_vol.value = Global.master_volume
	_lbl_vol_val.text = "%d%%" % int(Global.master_volume * 100.0)

func _on_settings_modified(_pressed: bool) -> void:
	Global.ShowFPS = _chk_fps.pressed
	Global.vsync_enabled = _chk_vsync.pressed
	Global.fullscreen_enabled = _chk_fullscreen.pressed
	Global.apply_settings()

func _on_settings_slider_changed(_val: float) -> void:
	Global.mouse_sensitivity = _sld_sens.value
	_lbl_sens_val.text = "%.2f" % Global.mouse_sensitivity
	Global.fov = _sld_fov.value
	_lbl_fov_val.text = "%d" % int(Global.fov)
	Global.master_volume = _sld_vol.value
	_lbl_vol_val.text = "%d%%" % int(Global.master_volume * 100.0)
	Global.apply_settings()

func _on_save_settings_pressed() -> void:
	Global.save_settings()
	Global.notify("Settings Saved & Applied!")
