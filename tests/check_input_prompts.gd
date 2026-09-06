extends SceneTree

const CONTROLS = preload("res://input_controls.gd")
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
	assert(CONTROLS.detect_family("Sony DualSense Wireless Controller") == CONTROLS.Family.PLAYSTATION)
	assert(CONTROLS.detect_family("PS4 Controller") == CONTROLS.Family.PLAYSTATION)
	assert(CONTROLS.detect_family("Xbox Wireless Controller") == CONTROLS.Family.XBOX)
	assert(CONTROLS.detect_family("XInput Gamepad") == CONTROLS.Family.XBOX)
	assert(CONTROLS.detect_family("USB Gamepad") == CONTROLS.Family.GENERIC)
	controls.set_device(CONTROLS.Family.PLAYSTATION, 3)
	assert(build.build_button.icon != null and not prep.back_button.text.contains("Esc"))
	var ps_icon: Texture2D = build.build_button.icon
	controls.set_device(CONTROLS.Family.XBOX, 3)
	assert(build.build_button.icon != ps_icon, "Xbox and PlayStation have distinct glyphs")
	assert(controls.hint("confirm_placement") == "A")
	controls.set_device(CONTROLS.Family.GENERIC, 3)
	assert(controls.hint("confirm_placement") == "Bottom button")
	var drift := InputEventJoypadMotion.new()
	drift.device = 3
	drift.axis = JOY_AXIS_LEFT_X
	drift.axis_value = 0.1
	controls.set_device(CONTROLS.Family.KEYBOARD)
	root.push_input(drift)
	assert(controls.family == CONTROLS.Family.KEYBOARD, "Drift does not switch prompts")
	assert(prep.place_button.icon == null)
	controls.set_device(CONTROLS.Family.PLAYSTATION, 3)
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(0.1, 0)
	root.push_input(mouse)
	assert(controls.family == CONTROLS.Family.PLAYSTATION, "Mouse jitter does not switch prompts")
	mouse.relative = Vector2(10, 0)
	root.push_input(mouse)
	assert(controls.family == CONTROLS.Family.KEYBOARD and not build.using_controller)
	# The first controller confirm activates the focused home action once.
	controls.set_device(CONTROLS.Family.GENERIC, 3)
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
	assert(scene.damage_level == 1 and scene.banked_energy == 440, "One press purchases exactly one upgrade")
	press(JOY_BUTTON_LEFT_SHOULDER)
	press(JOY_BUTTON_RIGHT_SHOULDER)
	assert(scene.damage_level == 1 and scene.fire_rate_level == 0, "Old shoulder shortcuts cannot purchase upgrades")
	# Keyboard still edits a name and restores keyboard prompts.
	var key := InputEventKey.new()
	key.physical_keycode = KEY_Z
	key.pressed = true
	root.push_input(key)
	assert(controls.family == CONTROLS.Family.KEYBOARD)
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
	controls.set_device(CONTROLS.Family.XBOX, 3)
	controls._connection_changed(3, false)
	assert(controls.family == CONTROLS.Family.KEYBOARD and not build.using_controller)
	scene.free()
	DirAccess.remove_absolute(path)
	print("PASS: controller families, glyphs, prompt switching, drift, menu focus, toolbar cursor, one-action confirm, upgrades, pause/results and disconnect")
	quit()
