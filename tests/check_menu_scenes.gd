extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("check")

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func check() -> void:
	ProjectSettings.set_setting("leaderboard/api_url", "")
	var theme := preload("res://game_theme.tres")
	var button_style := theme.get_stylebox("normal", "Button") as StyleBoxFlat
	var panel_style := theme.get_stylebox("panel", "DialogPanel") as StyleBoxFlat
	var button_color := button_style.bg_color
	var panel_color := panel_style.bg_color
	var scene = load("res://main.tscn").instantiate()
	scene.save_path = "/tmp/lll-menu-scenes-%d.json" % OS.get_process_id()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var prep = scene.get_node("PreparationUI")
	var pause = scene.get_node("PauseScreen")
	var results = scene.get_node("ResultsScreen")
	var settings = scene.get_node("SettingsScreen")
	expect(not pause.overlay.visible and not results.overlay.visible, "Editor-visible dialogs start closed in game")
	for view in [prep.View.HOME, prep.View.PLACEMENT, prep.View.UPGRADES, prep.View.RECORDS]:
		prep.open_view(view)
		await process_frame
		expect(button_style.bg_color == button_color and panel_style.bg_color == panel_color, "Preparation opacity never changes shared Theme resources")
		expect(pause.resume_button.get_theme_stylebox("normal") == button_style, "Pause inherits the shared button style")
		expect(settings.volume_button.get_theme_stylebox("normal") == button_style, "Settings inherits the shared button style")
	prep.open_view(prep.View.HOME)
	scene.start_run()
	pause.pause()
	for frame in range(6):
		await process_frame
	var initial_card: Control = pause.get_node("Overlay/Card")
	expect(absf(initial_card.size.y - initial_card.get_combined_minimum_size().y) < 1.0, "Pause fits content on first opening without resizing")
	for viewport_size in [Vector2i(720, 1360), Vector2i(640, 480), Vector2i(360, 640)]:
		root.size = viewport_size
		root.content_scale_size = viewport_size
		for frame in range(6):
			await process_frame
		var card: Control = pause.get_node("Overlay/Card")
		var viewport_rect := root.get_visible_rect()
		expect(card.get_global_rect().get_center().distance_to(viewport_rect.get_center()) < 1.0, "Pause card stays centered")
		expect(absf(card.size.y - card.get_combined_minimum_size().y) < 1.0, "Pause card height fits its content")
		for button in [pause.resume_button, pause.end_run_button, pause.settings_button]:
			expect(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(button.get_global_rect()), "Pause buttons fit small windows")
	# Text wrapping and switching input devices can change the minimum height
	# after the dialog has opened, without a viewport resize.
	for hint_visible in [true, false, true]:
		pause.keys.visible = hint_visible
		for frame in range(6):
			await process_frame
		expect(absf(initial_card.size.y - initial_card.get_combined_minimum_size().y) < 1.0, "Pause refits when keyboard hints change")
		expect(initial_card.get_global_rect().get_center().distance_to(root.get_visible_rect().get_center()) < 1.0, "Pause stays centered when keyboard hints change")
	pause.resume()
	scene.free()
	DirAccess.remove_absolute("/tmp/lll-menu-scenes-%d.json" % OS.get_process_id())
	await process_frame
	if failures == 0:
		print("PASS: shared Theme stays isolated; pause fits content and stays centered across window sizes and hint changes")
	quit(1 if failures else 0)
