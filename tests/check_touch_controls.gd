extends SceneTree


func _initialize() -> void:
	call_deferred("check")


func touch(index: int, point: Vector2, pressed: bool, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	root.push_input(event, true)


func drag(index: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	root.push_input(event, true)


func check() -> void:
	root.size = Vector2i(844, 390)
	var scene = load("res://main.tscn").instantiate()
	var path := "/tmp/little-last-light-touch-%d.json" % OS.get_process_id()
	scene.save_path = path
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var controls = scene.get_node("TouchLayer/TouchControls")
	var lantern = scene.lantern
	touch(0, Vector2(40, 250), true)
	assert(controls.enabled and controls.finger == -1, "Menu touch detects touchscreen without moving")
	touch(0, Vector2(40, 250), false)
	var prep = scene.get_node("PreparationUI")
	prep.open_view(prep.View.UPGRADES)
	for frame in range(4):
		await process_frame
	assert(is_instance_valid(prep.touch_scroll), "Touch preparation uses a scrollable card")
	assert(prep.card.scale == Vector2.ONE, "Phone menus retain readable sizes")
	assert(prep.upgrade_groups.columns == 2, "Landscape phone upgrades use two columns")
	assert(scene.get_node("BuildController").damage_button.size.y >= 44, "Upgrade buttons remain thumb-sized")
	assert(root.get_visible_rect().encloses(prep.card.get_global_rect()), "Phone card fits in the viewport")
	prep.open_view(prep.View.PLACEMENT)
	assert(prep.blocks_point(prep.card.get_global_rect().get_center()), "Scrolling a placement card cannot place behind it")
	prep.open_view(prep.View.HOME)
	var settings = scene.get_node("SettingsScreen")
	settings.open(prep.settings_button)
	for frame in range(4):
		await process_frame
	var settings_back: Button = settings.menu.get_node("BackButton")
	assert(settings.menu.get_node("Center") is ScrollContainer, "Phone settings scroll instead of shrinking")
	assert(settings.volume_button.get_global_rect().size.y >= 44, "Phone settings retain readable buttons")
	assert(settings_back.get_global_rect().size.y >= 48, "Settings Back stays thumb-sized")
	assert(settings.menu.get_node("Center").position.y > settings_back.get_global_rect().end.y, "Settings scroll below the fixed Back button")
	settings._show_visual(true)
	settings.menu.get_node("Center").scroll_vertical = 100
	var back_mouse := InputEventMouseButton.new()
	back_mouse.position = settings_back.get_global_rect().get_center()
	back_mouse.button_index = MOUSE_BUTTON_LEFT
	back_mouse.pressed = true
	root.push_input(back_mouse, true)
	back_mouse.pressed = false
	root.push_input(back_mouse, true)
	assert(settings.is_open() and not settings.visual_open, "Pointer Back leaves a scrolled settings subpage")
	back_mouse.pressed = true
	root.push_input(back_mouse, true)
	back_mouse.pressed = false
	root.push_input(back_mouse, true)
	assert(not settings.is_open(), "Pointer Back exits settings without a keyboard")
	scene.start_run()
	controls._process(0)
	assert(controls.visible and not scene.get_node("GameHUD").brightness_indicator.visible)
	var origin := Vector2(120, 240)
	touch(3, origin, true)
	assert(controls.finger == 3, "Left thumb owns joystick")
	drag(3, origin + Vector2(5, 0))
	assert(lantern.touch_direction == Vector2.ZERO, "Deadzone prevents drift")
	drag(3, origin + Vector2(34, 0))
	assert(is_equal_approx(lantern.touch_direction.x, 0.5), "Partial throw gives analog speed")
	drag(3, origin + Vector2(150, 150))
	assert(is_equal_approx(lantern.touch_direction.length(), 1.0), "Diagonal speed is capped")
	var before: Vector2 = lantern.position
	lantern._physics_process(0.1)
	assert(is_equal_approx(lantern.position.distance_to(before), lantern.move_speed * 0.1), "Touch moves lantern at normal maximum speed")
	var brightness_point: Vector2 = controls.brightness_button.get_global_rect().get_center()
	touch(7, brightness_point, true)
	drag(7, brightness_point + Vector2(1, 1))
	assert(controls.finger == 3 and lantern.brightness == 0, "Second finger does not steal movement")
	touch(7, brightness_point, false)
	assert(lantern.brightness == 1 and lantern.touch_direction.length() > 0, "Brightness works while moving")
	var mouse := InputEventMouseButton.new()
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	mouse.position = brightness_point
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	root.push_input(mouse)
	mouse.pressed = false
	root.push_input(mouse)
	assert(lantern.brightness == 1, "Emulated mouse does not double-activate brightness")
	touch(7, brightness_point, true)
	touch(7, brightness_point, false, true)
	assert(lantern.brightness == 1, "Canceled button touch does not activate")
	touch(3, origin, false)
	assert(lantern.touch_direction == Vector2.ZERO and controls.finger == -1, "Release stops movement")
	touch(3, origin, true)
	drag(3, origin + Vector2(58, 0))
	var pause_point: Vector2 = controls.pause_button.get_global_rect().get_center()
	touch(8, pause_point, true)
	touch(8, pause_point, false)
	assert(paused and lantern.touch_direction == Vector2.ZERO, "Pause clears held movement")
	scene.get_node("PauseScreen").resume()
	drag(3, origin + Vector2(58, 0))
	assert(lantern.touch_direction == Vector2.ZERO, "Old finger cannot restart movement after resume")
	touch(3, origin, true)
	drag(3, origin + Vector2(58, 0))
	controls._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert(paused and lantern.touch_direction == Vector2.ZERO, "Browser focus loss pauses and clears touch")
	scene.get_node("PauseScreen").resume()
	touch(3, origin, true)
	drag(3, origin + Vector2(58, 0))
	controls._layout()
	assert(lantern.touch_direction == Vector2.ZERO, "Resize clears touch coordinates")
	touch(3, origin, true)
	drag(3, origin + Vector2(58, 0))
	scene.end_run(true)
	assert(lantern.touch_direction == Vector2.ZERO, "Run ending clears movement")
	controls._process(0)
	assert(not controls.visible, "Results hide combat controls")
	scene.free()
	DirAccess.remove_absolute(path)
	print("PASS: touch detection, deadzone, analog movement, diagonal cap, multitouch brightness, mouse deduplication, cancellation, pause, focus loss, resize, results")
	quit()
