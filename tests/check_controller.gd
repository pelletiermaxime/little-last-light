extends SceneTree


func _initialize() -> void:
	call_deferred("check")


func press(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 3 # Bindings must work beyond the first connected controller.
	event.button_index = button
	event.pressed = true
	root.push_input(event)
	event.pressed = false
	root.push_input(event)


func axis(value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 3
	event.axis = JOY_AXIS_LEFT_X
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func check() -> void:
	var scene = load("res://main.tscn").instantiate()
	var path := "/tmp/little-last-light-controller-%d.json" % OS.get_process_id()
	scene.save_path = path
	root.add_child(scene)
	current_scene = scene
	var build = scene.get_node("BuildController")
	scene.banked_energy = 40.0
	press(JOY_BUTTON_X)
	assert(build.placing and build.using_controller, "Square starts controller placement")
	press(JOY_BUTTON_START)
	assert(scene.phase == scene.Phase.PREPARATION, "Cannot start during placement")
	press(JOY_BUTTON_B)
	assert(not build.placing and scene.banked_energy == 40.0, "Circle cancels without spending")
	axis(0.1)
	assert(Input.get_vector("move_left", "move_right", "move_up", "move_down") == Vector2.ZERO, "Stick drift stays inside deadzone")
	axis(1.0)
	var before: Vector2 = build.controller_cursor
	build._process(0.1)
	assert(build.controller_cursor.x > before.x, "Stick moves preparation cursor")
	axis(0.0)
	build.controller_cursor = scene.get_arena_rect().size * Vector2(0.2, 0.3)
	press(JOY_BUTTON_X)
	press(JOY_BUTTON_A)
	assert(not build.placing and scene.banked_energy == 20.0, "Cross buys at cursor")
	assert(get_nodes_in_group("turrets").size() == 2, "One turret purchased")
	press(JOY_BUTTON_A)
	assert(build.placing and is_instance_valid(build.selected_turret), "Cross selects existing turret")
	build.controller_cursor += Vector2(0, 50)
	press(JOY_BUTTON_A)
	assert(not build.placing and scene.banked_energy == 20.0, "Moving turret is free")
	press(JOY_BUTTON_START)
	assert(scene.lantern.running, "Options starts run")
	assert(scene.lantern.brightness == 0, "Preparation confirm does not change brightness")
	press(JOY_BUTTON_A)
	assert(scene.lantern.brightness == 1, "Cross changes brightness in combat")
	axis(1.0)
	before = scene.lantern.position
	scene.lantern._physics_process(0.1)
	assert(scene.lantern.position.x > before.x, "Stick moves lantern")
	axis(0.0)
	press(JOY_BUTTON_X)
	assert(not build.placing, "Controller cannot build during combat")
	scene.lantern.take_damage(1000)
	press(JOY_BUTTON_START)
	assert(scene.lantern.running, "Controller starts another run after defeat")
	scene.free()
	DirAccess.remove_absolute(path)
	print("PASS: controller cursor, deadzone, placement, cancel, move, start, brightness, movement, combat lock, restart")
	quit()
