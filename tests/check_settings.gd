extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("check")

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event)
	event.pressed = false
	root.push_input(event)

func joy(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	root.push_input(event)
	event.pressed = false
	root.push_input(event)

func check() -> void:
	var display = root.get_node("DisplaySettings")
	display.settings_path = "/tmp/lll-settings-%d.cfg" % OS.get_process_id()
	display.windowed_size = Vector2i.ZERO
	expect(display.fitted_window_size(Vector2i(2560, 1440)) == Vector2i(2176, 1224), "Default window uses 85 percent of usable screen")
	display.windowed_size = Vector2i(1500, 900)
	expect(display.fitted_window_size(Vector2i(2560, 1440)) == Vector2i(1500, 900), "Custom window size is preserved")
	expect(display.fitted_window_size(Vector2i(1280, 720)) == Vector2i(1248, 656), "Saved window fits a smaller display")
	display.save_settings()
	display.windowed_size = Vector2i.ZERO
	display.load_settings()
	expect(display.windowed_size == Vector2i(1500, 900), "Custom window size survives restart")
	var legacy := ConfigFile.new()
	legacy.set_value("display", "windowed_size", Vector2i(1280, 720))
	legacy.save(display.settings_path)
	display.load_settings()
	expect(display.windowed_size == Vector2i.ZERO, "Old fixed default migrates to adaptive sizing")
	display.windowed_size = Vector2i(1280, 720)
	display.save_settings()
	display.load_settings()
	expect(display.windowed_size == Vector2i(1280, 720), "New explicitly chosen 1280x720 size is retained")
	display.windowed_size = Vector2i(1500, 900)
	display.display_mode = "Windowed"
	display.save_settings()
	display.windowed_size = Vector2i.ZERO
	display.load_settings()
	root.borderless = true
	display._apply_window(root, Rect2i(0, 0, 2560, 1440))
	await process_frame
	expect(root.size == Vector2i(1500, 900) and not root.borderless, "Restart restores saved geometry on the root Window")
	expect(root.position == Vector2i(530, 270), "Restored window is centered")
	expect(display._capture_window_state(Window.MODE_MAXIMIZED, Vector2i(2560, 1440)), "Window-manager maximize is recorded")
	expect(display.windowed_maximized and display.windowed_size == Vector2i(1500, 900), "Maximize preserves normal window size")
	display.save_settings()
	display.windowed_maximized = false
	display.load_settings()
	expect(display.windowed_maximized, "Maximized state survives restart")
	display._apply_window(root, Rect2i(0, 0, 2560, 1440))
	# The headless display driver cannot actually maximize a native window.
	if display.desktop_controls():
		expect(root.mode == Window.MODE_MAXIMIZED, "Saved maximized state is applied to the root Window")
	expect(not display._capture_window_state(Window.MODE_MINIMIZED, Vector2i(1, 1)), "Minimizing does not overwrite window state")
	expect(not display._capture_window_state(Window.MODE_FULLSCREEN, Vector2i(2560, 1440)), "Fullscreen does not overwrite window state")
	expect(display._capture_window_state(Window.MODE_WINDOWED, Vector2i(1500, 900)), "Unmaximize clears saved maximized state")
	expect(not display.windowed_maximized, "Next launch can restore a normal window")
	display._apply_window(root, Rect2i(0, 0, 2560, 1440))
	for limit in [60, 100, 0]:
		display.set_fps_limit(limit)
		expect(Engine.max_fps == limit, "FPS limit applies immediately")
	display.set_fps_limit(45)
	expect(Engine.max_fps == 0, "Unsupported FPS limits are rejected")
	for mode in display.DISPLAY_MODES:
		display.set_display_mode(mode)
		expect(display.display_mode == mode, "All three display modes can be selected")
	display.set_display_mode("Borderless fullscreen")
	display.set_display_mode("invalid")
	expect(display.display_mode == "Borderless fullscreen", "Invalid display modes are rejected")
	display.set_fps_limit(100)
	display.set_vsync(false)
	display.fps_limit = 60
	display.vsync = true
	display.display_mode = "Windowed"
	display.load_settings()
	display.apply()
	expect(display.fps_limit == 100 and Engine.max_fps == 100 and not display.vsync and display.display_mode == "Borderless fullscreen", "Display preferences reload")
	display.set_fps_limit(0)
	root.size = Vector2i(640, 480)
	var scene = load("res://main.tscn").instantiate()
	scene.save_path = "/tmp/lll-settings-%d.json" % OS.get_process_id()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var prep = scene.get_node("PreparationUI")
	var settings = scene.get_node("SettingsScreen")
	var controls = scene.get_node("Controls")
	var pause = scene.get_node("PauseScreen")
	prep.settings_button.pressed.emit()
	expect(settings.is_open() and not paused, "Settings opens from preparation")
	for size in [Vector2i(640, 480), Vector2i(360, 640)]:
		root.size = size
		for frame in range(6):
			await process_frame
		for button in [settings.volume_button, settings.mute_button, settings.display_mode_button, settings.fps_button, settings.vsync_button, settings.done_button]:
			expect(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(button.get_global_rect()), "Settings buttons fit small viewports")
	settings.fps_button.grab_focus()
	joy(JOY_BUTTON_A)
	expect(display.fps_limit == 60, "Controller changes setting exactly once")
	key(KEY_B)
	joy(JOY_BUTTON_RIGHT_STICK)
	key(KEY_ENTER)
	expect(not scene.get_node("BuildController").placing and scene.phase == scene.Phase.PREPARATION, "Settings blocks gameplay shortcuts")
	joy(JOY_BUTTON_B)
	expect(not settings.is_open() and root.gui_get_focus_owner() == prep.settings_button, "Controller Back restores main menu focus")
	scene.start_run()
	pause.pause()
	pause.settings_button.pressed.emit()
	var elapsed: float = scene.lantern.elapsed
	await process_frame
	expect(settings.is_open() and paused and scene.lantern.elapsed == elapsed, "Run stays frozen in settings")
	expect(controls.menu_controls().has(settings.fps_button) and not controls.menu_controls().has(pause.resume_button), "Controller focus stays in settings")
	key(KEY_ESCAPE)
	expect(not settings.is_open() and paused and root.gui_get_focus_owner() == pause.settings_button, "Escape returns to pause without resuming")
	pause.resume()
	var path: String = scene.save_path
	scene.free()
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(display.settings_path)
	Engine.max_fps = 0
	if failures == 0:
		print("PASS: display persistence, FPS limits, menu entry, controller settings, back focus, pause isolation, small layouts")
	quit(1 if failures else 0)
