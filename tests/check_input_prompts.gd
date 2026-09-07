extends SceneTree

var scene: Node2D
var controls: Node


func _initialize() -> void:
	call_deferred("check")


func press(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 3
	event.button_index = button
	event.pressed = true
	root.push_input(event)
	event.pressed = false
	root.push_input(event)


func keyboard() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_Z
	event.pressed = true
	root.push_input(event)


func move_stick(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 3
	event.axis = axis
	event.axis_value = value
	root.push_input(event)


func check() -> void:
	scene = load("res://main.tscn").instantiate()
	var path := "/tmp/little-last-light-prompts-%d.json" % OS.get_process_id()
	scene.save_path = path
	root.add_child(scene)
	current_scene = scene
	controls = scene.get_node("Controls")
	var build = scene.get_node("BuildController")
	var prep = scene.get_node("PreparationUI")
	await process_frame
	var prompts := root.get_node("ControllerIcons")
	press(JOY_BUTTON_RIGHT_STICK)
	assert(controls.using_controller() and build.using_controller)
	assert(build.build_button.icon != null and not prep.back_button.text.contains("Esc"))
	# A synthetic, disconnected device exercises the addon's default fallback.
	assert(build.build_button.icon == prompts.parse_path("build_turret"))
	for action in ["build_turret", "build_pulse_turret", "cancel_placement", "toggle_build_controls", "sell_turret", "cycle_brightness", "pause_run", "confirm_placement"]:
		var icon: Texture2D = controls.icon_for(action)
		assert(icon != null and icon.resource_path.begins_with("res://addons/controller_icons/assets/"), "Every controller prompt must use addon artwork: " + action)
	assert(build.cancel_button.icon == prompts.parse_path("cancel_placement"))
	assert(build.sell_button.icon == prompts.parse_path("sell_turret"))
	assert(prep.show_button.icon == prompts.parse_path("toggle_build_controls"))
	assert(scene.get_node("GameHUD").brightness_indicator.prompt_icon == prompts.parse_path("cycle_brightness"))
	assert(controls.hint("sell_turret") == prompts.parse_path_to_tts("sell_turret"))
	var drift := InputEventJoypadMotion.new()
	drift.device = 3
	drift.axis = JOY_AXIS_LEFT_X
	drift.axis_value = 0.1
	keyboard()
	root.push_input(drift)
	assert(not controls.using_controller(), "Drift does not switch prompts")
	assert(prep.place_button.icon == null)
	press(JOY_BUTTON_RIGHT_STICK)
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(0.1, 0)
	root.push_input(mouse)
	assert(controls.using_controller(), "Mouse jitter does not switch prompts")
	mouse.relative = Vector2(100, 0)
	root.push_input(mouse)
	assert(not controls.using_controller() and not build.using_controller)
	# The first controller confirm activates the focused home action once.
	press(JOY_BUTTON_RIGHT_STICK)
	prep.place_button.grab_focus()
	move_stick(JOY_AXIS_LEFT_Y, 0.8)
	var first_step := root.gui_get_focus_owner()
	assert(first_step != prep.place_button, "Stick moves focus immediately")
	for i in range(10):
		move_stick(JOY_AXIS_LEFT_X, 0.02 if i % 2 == 0 else -0.02)
		move_stick(JOY_AXIS_LEFT_Y, 0.8)
		assert(root.gui_get_focus_owner() == first_step, "Other-axis jitter cannot bypass repeat delay")
	controls._process(0.34)
	assert(root.gui_get_focus_owner() == first_step, "Held stick waits before repeating")
	controls._process(0.02)
	var second_step := root.gui_get_focus_owner()
	assert(second_step != first_step, "Held stick repeats after initial delay")
	controls._process(0.10)
	assert(root.gui_get_focus_owner() == second_step, "Repeat interval limits navigation")
	move_stick(JOY_AXIS_LEFT_Y, 0.0)
	controls._process(0.5)
	assert(root.gui_get_focus_owner() == second_step, "Returning to neutral stops repeat")
	move_stick(JOY_AXIS_LEFT_X, 0.0)
	prep.place_button.grab_focus()
	controls.refresh_prompts()
	assert(prep.place_button.icon == null and prep.upgrades_button.icon == null, "Standard confirmation needs no menu icons")
	press(JOY_BUTTON_A)
	assert(prep.view == prep.View.PLACEMENT and not build.placing)
	assert(root.gui_get_focus_owner() == null, "Placement starts with world cursor")
	scene.banked_energy = 500
	build._update_interface()
	press(JOY_BUTTON_X)
	assert(build.placing)
	press(JOY_BUTTON_Y)
	assert(prep.controls_hidden and build.placing and scene.banked_energy == 500, "Hide shortcut cannot refund layout")
	press(JOY_BUTTON_Y)
	assert(not prep.controls_hidden and build.placing)
	press(JOY_BUTTON_B)
	assert(not build.placing and prep.view == prep.View.PLACEMENT)
	press(JOY_BUTTON_LEFT_SHOULDER)
	assert(build.placing and build.preview.turret_type == "pulse", "L1/LB begins pulse placement")
	assert(build.pulse_button.icon == prompts.parse_path("build_pulse_turret"), "Pulse shows mapped shoulder icon")
	press(JOY_BUTTON_B)
	var cursor: Vector2 = build.controller_cursor
	press(JOY_BUTTON_DPAD_DOWN)
	assert(root.gui_get_focus_owner() != null, "D-pad selects toolbar")
	build._process(0.1)
	assert(build.controller_cursor == cursor, "Toolbar navigation does not move cursor")
	var motion := InputEventJoypadMotion.new()
	motion.device = 3
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = 0.8
	root.push_input(motion)
	assert(root.gui_get_focus_owner() == null, "Stick returns control to world cursor")
	press(JOY_BUTTON_B)
	assert(prep.view == prep.View.HOME)
	prep.upgrades_button.grab_focus()
	press(JOY_BUTTON_A)
	assert(prep.view == prep.View.UPGRADES)
	build.damage_button.grab_focus()
	press(JOY_BUTTON_A)
	assert(scene.damage_level == 1 and scene.banked_energy == 380, "One press purchases exactly one upgrade")
	press(JOY_BUTTON_LEFT_SHOULDER)
	press(JOY_BUTTON_RIGHT_SHOULDER)
	assert(scene.damage_level == 1 and scene.fire_rate_level == 0, "Old shoulder shortcuts cannot purchase upgrades")
	assert(build.placing and build.preview.turret_type == "pulse", "Left shoulder opens pulse placement from preparation menus")
	press(JOY_BUTTON_B)
	# Keyboard still edits a name and restores keyboard prompts.
	var key := InputEventKey.new()
	key.physical_keycode = KEY_Z
	key.pressed = true
	root.push_input(key)
	assert(not controls.using_controller())
	press(JOY_BUTTON_B)
	build.start_button.grab_focus()
	press(JOY_BUTTON_A)
	assert(scene.lantern.running and scene.lantern.brightness == 0, "Start confirm does not also change brightness")
	press(JOY_BUTTON_A)
	assert(scene.lantern.brightness == 1)
	press(JOY_BUTTON_START)
	assert(paused)
	var pause = scene.get_node("PauseScreen")
	assert(root.gui_get_focus_owner() == pause.resume_button)
	press(JOY_BUTTON_DPAD_DOWN)
	assert(root.gui_get_focus_owner() == pause.end_run_button)
	press(JOY_BUTTON_A)
	assert(not paused and scene.phase == scene.Phase.RESULTS)
	press(JOY_BUTTON_A)
	assert(scene.phase == scene.Phase.PREPARATION and not scene.lantern.running, "Continue cannot immediately start another run")
	press(JOY_BUTTON_RIGHT_STICK)
	prompts._on_joy_connection_changed(3, false)
	assert(controls.using_controller() == not Input.get_connected_joypads().is_empty(), "Addon keeps another connected controller active on disconnect")
	assert(build.using_controller == controls.using_controller())
	scene.free()
	DirAccess.remove_absolute(path)
	print("PASS: addon detection, artwork, prompt switching, drift, menu focus, toolbar cursor, one-action confirm, upgrades, pause/results and disconnect")
	quit()
