extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("check")

func expect_focus(control: Control, message: String) -> void:
	if root.gui_get_focus_owner() != control:
		failures += 1
		printerr("FAIL: " + message)

func press(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 3
	event.button_index = button
	event.pressed = true
	root.push_input(event)
	event.pressed = false
	root.push_input(event)

func check() -> void:
	var scene = load("res://main.tscn").instantiate()
	var path := "/tmp/lll-menu-focus-%d.json" % OS.get_process_id()
	scene.save_path = path
	root.add_child(scene)
	current_scene = scene
	scene.set_process(false)
	var prep = scene.get_node("PreparationUI")
	var build = scene.get_node("BuildController")
	var controls = scene.get_node("Controls")
	var settings = scene.get_node("SettingsScreen")
	var panel = scene.get_node("GameHUD").leaderboard
	panel.api_url = ""
	await process_frame
	await process_frame
	press(JOY_BUTTON_LEFT_STICK)
	expect_focus(build.start_button, "Home defaults to Start")
	prep.upgrades_button.grab_focus()
	press(JOY_BUTTON_A)
	expect_focus(build.damage_button, "Upgrades starts at its first upgrade")
	press(JOY_BUTTON_B)
	expect_focus(prep.upgrades_button, "Back restores the Upgrades entry button")
	prep.records_button.grab_focus()
	press(JOY_BUTTON_A)
	press(JOY_BUTTON_B)
	expect_focus(prep.records_button, "Back restores the Records entry button")
	prep.open_view(prep.View.PLACEMENT)
	controls._process(0.1)
	expect_focus(null, "Placement leaves the arena cursor in control")
	press(JOY_BUTTON_B)
	expect_focus(prep.place_button, "Back restores the Placement entry button")
	settings.open(prep.settings_button)
	expect_focus(settings.volume_button, "Settings defaults to Volume")
	settings._show_visual(true)
	expect_focus(settings.visual_page.get_node("StrongDangerCues"), "Visual settings defaults to the first option")
	press(JOY_BUTTON_B)
	expect_focus(settings.visual_button, "Back restores the Visual settings entry")
	settings._ask_reset()
	expect_focus(settings.reset_cancel, "Destructive confirmation defaults to Cancel")
	press(JOY_BUTTON_B)
	expect_focus(settings.reset_button, "Cancel restores Reset progress")
	press(JOY_BUTTON_B)
	expect_focus(prep.settings_button, "Closing Settings restores its entry button")
	# Recovery must choose Home's default, not whichever end a direction implies.
	prep.settings_button.release_focus()
	controls._process(0.1)
	expect_focus(build.start_button, "Lost controller focus recovers to the current menu default")
	prep.records_button.grab_focus()
	controls._process(0.1)
	expect_focus(prep.records_button, "Recovery preserves an existing valid selection")
	scene.start_run()
	scene.lantern.elapsed = 236
	scene.end_run(true)
	var results = scene.get_node("ResultsScreen")
	expect_focus(results.continue_button, "Results defaults to Continue")
	results.page_button.grab_focus()
	press(JOY_BUTTON_A)
	expect_focus(panel.username, "Record form selects the username field on entry")
	panel.skip.grab_focus()
	press(JOY_BUTTON_A)
	controls._process(0.1)
	if root.gui_get_focus_owner() == null or root.gui_get_focus_owner() not in controls.menu_controls():
		failures += 1
		printerr("FAIL: Skipping publication must leave a visible selectable control")
	var scores: Array = []
	for index in range(4):
		scores.append({"rank": index + 1, "username": "Player", "durationMs": 1000})
	panel._scores_completed(HTTPRequest.RESULT_SUCCESS, 200, [], JSON.stringify(scores).to_utf8_buffer())
	panel.next_page.grab_focus()
	press(JOY_BUTTON_A)
	controls._process(0.1)
	expect_focus(panel.previous_page, "Last ranking page moves focus off disabled Next onto Previous")
	panel._load_scores()
	controls._process(0.1)
	if root.gui_get_focus_owner() == null or root.gui_get_focus_owner() not in controls.menu_controls():
		failures += 1
		printerr("FAIL: Reloading rankings must recover focus when paging controls disappear")
	press(JOY_BUTTON_B)
	expect_focus(results.page_button, "Leaving results leaderboard restores its entry button")
	scene.free()
	DirAccess.remove_absolute(path)
	if failures == 0:
		print("PASS: menu defaults, controller back paths, focus recovery, publication skip, safe reset default, placement cursor")
	quit(1 if failures else 0)
