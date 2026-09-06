extends SceneTree

var scene: Node2D

func _initialize() -> void:
	call_deferred("check")

func settle() -> void:
	for frame in range(6):
		await process_frame

func visible_inside(control: Control) -> void:
	assert(control.is_visible_in_tree(), "Action must be visible")
	assert(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(control.get_global_rect()), "Action must fit in the viewport")

func check() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(640, 480)
	var path := "/tmp/lll-menu-pages-%d.json" % OS.get_process_id()
	scene = load("res://main.tscn").instantiate()
	scene.save_path = path
	root.add_child(scene)
	current_scene = scene
	scene.set_process(false)
	var panel = scene.get_node("GameHUD").leaderboard
	panel.api_url = ""
	await settle()
	scene.start_run()
	scene.lantern.elapsed = 236
	scene.lantern.energy = 1383
	scene.end_run(true)
	var results = scene.get_node("ResultsScreen")
	await settle()
	assert(scene.find_children("*", "ScrollContainer", true, false).is_empty(), "Game menus have no scroll containers")
	visible_inside(results.continue_button)
	visible_inside(results.page_button)
	assert(not panel.is_visible_in_tree(), "Summary has its own page")
	results.page_button.pressed.emit()
	await settle()
	visible_inside(panel.publish)
	visible_inside(panel.username)
	visible_inside(results.continue_button)
	panel.notice.text = "Publishing failed. Your record is saved; try again."
	panel.rankings_button.pressed.emit()
	var scores: Array = []
	for index in range(10):
		scores.append({"rank": index + 1, "username": "Long_username_1234567", "durationMs": 474629, "energyInvested": 3290})
	panel._scores_completed(HTTPRequest.RESULT_SUCCESS, 200, [], JSON.stringify(scores).to_utf8_buffer())
	await settle()
	assert(panel.scores_rows.get_child_count() == 3)
	visible_inside(panel.next_page)
	visible_inside(panel.refresh_scores)
	visible_inside(results.continue_button)
	var controls = scene.get_node("Controls")
	controls.set_device(controls.Family.PLAYSTATION, 3)
	panel.next_page.grab_focus()
	var event := InputEventJoypadButton.new()
	event.device = 3
	event.button_index = JOY_BUTTON_A
	event.pressed = true
	root.push_input(event)
	event.pressed = false
	root.push_input(event)
	assert(panel.page_index == 1 and panel.scores_rows.get_child(0).text.begins_with("#4"), "Controller advances exactly one leaderboard page")
	panel._change_page(2)
	assert(panel.scores_rows.get_child_count() == 1 and panel.next_page.disabled)
	results.continue_button.pressed.emit()
	var prep = scene.get_node("PreparationUI")
	for view in [0, 1, 2, 3]:
		prep.open_view(view)
		await settle()
		visible_inside(prep.card)
		for button in controls.menu_controls():
			visible_inside(button)
	scene.free()
	DirAccess.remove_absolute(path)
	print("PASS: no scroll containers, visible results footer, submission and ranking pages, controller pagination, all preparation menus fit at 640x480")
	quit()
