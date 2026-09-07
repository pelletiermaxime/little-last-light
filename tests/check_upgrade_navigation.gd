extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func joy(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 3
	event.button_index = button
	event.pressed = true
	root.push_input(event)
	event.pressed = false
	root.push_input(event)

func stick(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 3
	event.axis = axis
	event.axis_value = value
	root.push_input(event)

func settle() -> void:
	for frame in range(6):
		await process_frame

func check() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.save_path = "/tmp/lll-navigation-unused-%d.json" % OS.get_process_id()
	root.add_child(scene)
	current_scene = scene
	scene.banked_energy = 10000
	root.size = Vector2i(1280, 800)
	var prep = scene.get_node("PreparationUI")
	var build = scene.get_node("BuildController")
	var controls = scene.get_node("Controls")
	prep.open_view(prep.View.UPGRADES)
	await settle()
	build.damage_button.grab_focus()
	joy(JOY_BUTTON_DPAD_RIGHT)
	assert(root.gui_get_focus_owner() == prep.slow_buttons.slow_rate, "Right moves across groups rather than down to fire rate")
	joy(JOY_BUTTON_DPAD_RIGHT)
	assert(root.gui_get_focus_owner() == build.health_button)
	joy(JOY_BUTTON_DPAD_LEFT)
	assert(root.gui_get_focus_owner() == prep.slow_buttons.slow_rate)
	joy(JOY_BUTTON_DPAD_DOWN)
	assert(root.gui_get_focus_owner() == prep.slow_buttons.slow_strength)
	joy(JOY_BUTTON_DPAD_UP)
	assert(root.gui_get_focus_owner() == prep.slow_buttons.slow_rate)
	build.damage_button.grab_focus()
	stick(JOY_AXIS_LEFT_X, 0.8)
	assert(root.gui_get_focus_owner() == prep.slow_buttons.slow_rate, "Stick uses horizontal neighbors")
	controls._process(0.36)
	assert(root.gui_get_focus_owner() == build.health_button, "Held-stick repeat preserves axis")
	stick(JOY_AXIS_LEFT_X, 0)
	prep.slow_buttons.slow_rate.grab_focus()
	stick(JOY_AXIS_LEFT_Y, 0.8)
	assert(root.gui_get_focus_owner() == prep.slow_buttons.slow_strength)
	stick(JOY_AXIS_LEFT_Y, 0)
	# Reproduce the reported layout: only health and slow duration are affordable.
	scene.damage_level = 4
	scene.fire_rate_level = 4
	scene.health_level = 2
	scene.slow_levels = {"slow_rate": 2, "slow_strength": 2, "slow_duration": 1}
	scene.banked_energy = 180
	build._update_interface()
	build.health_button.grab_focus()
	joy(JOY_BUTTON_DPAD_LEFT)
	assert(root.gui_get_focus_owner() == prep.slow_buttons.slow_rate, "Can leave Lantern through an unaffordable upgrade")
	joy(JOY_BUTTON_DPAD_LEFT)
	assert(root.gui_get_focus_owner() == build.damage_button, "Maxed upgrades remain reachable")
	var funds: float = scene.banked_energy
	joy(JOY_BUTTON_A)
	assert(scene.damage_level == 4 and scene.banked_energy == funds, "Confirming a maxed upgrade cannot spend")
	joy(JOY_BUTTON_DPAD_DOWN)
	assert(root.gui_get_focus_owner() == build.rate_button)
	joy(JOY_BUTTON_DPAD_RIGHT)
	assert(root.gui_get_focus_owner() == prep.slow_buttons.slow_strength)
	joy(JOY_BUTTON_A)
	assert(scene.slow_levels.slow_strength == 2 and scene.banked_energy == funds, "Confirming an unaffordable upgrade cannot spend")
	joy(JOY_BUTTON_DPAD_DOWN)
	assert(root.gui_get_focus_owner() == prep.slow_buttons.slow_duration)
	root.size = Vector2i(1280, 600)
	root.content_scale_size = Vector2i(1280, 600)
	await settle()
	prep.slow_buttons.slow_duration.grab_focus()
	await settle()
	var duration_progress: Control = prep.upgrade_progress.slow_duration
	assert(prep.upgrade_panel.get_global_rect().encloses(duration_progress.get_global_rect()), "Duration progress fits below the button without scrolling")
	for group in prep.upgrade_groups.get_children():
		assert(root.get_visible_rect().encloses(group.get_child(0).get_global_rect()), "Group title remains visible")
	for indicator in prep.upgrade_progress.values():
		assert(root.get_visible_rect().encloses(indicator.get_global_rect()), "All progress indicators fit together")
	# At small sizes, the full page scales while retaining directional neighbors.
	root.size = Vector2i(640, 480)
	root.content_scale_size = Vector2i(640, 480)
	await settle()
	assert(prep.upgrade_groups.columns == 3)
	build.rate_button.grab_focus()
	await settle()
	var expected: Control = build.rate_button.find_valid_focus_neighbor(SIDE_BOTTOM)
	joy(JOY_BUTTON_DPAD_DOWN)
	assert(root.gui_get_focus_owner() == expected)
	await settle()
	assert(root.get_visible_rect().encloses(expected.get_global_rect()))
	prep.go_back()
	build.start_button.grab_focus()
	joy(JOY_BUTTON_DPAD_RIGHT)
	assert(root.gui_get_focus_owner() == prep.place_button, "Other vertical menus retain their existing navigation")
	scene.free()
	print("PASS: spatial D-pad/stick, horizontal repeats, vertical groups, compact page fit, other menu navigation")
	quit()
