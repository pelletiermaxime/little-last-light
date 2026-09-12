extends SceneTree

var path := "/tmp/lll-achievement-ui-%d.json" % OS.get_process_id()


func _initialize() -> void:
	call_deferred("check")


func settle() -> void:
	for frame in range(6):
		await process_frame


func check() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(960, 720)
	var scene = load("res://main.tscn").instantiate()
	scene.save_path = path
	root.add_child(scene)
	current_scene = scene
	scene.achievements.api_url = ""
	scene.get_node("GameHUD").leaderboard.api_url = ""
	scene.set_process(false)
	var prep = scene.get_node("PreparationUI")
	var toast = scene.get_node("AchievementToasts")
	await settle()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(960, 720)
	await settle()
	assert(prep.achievements_button.is_visible_in_tree())
	prep.achievements_button.pressed.emit()
	await settle()
	assert(prep.view == prep.View.ACHIEVEMENTS)
	assert(prep.achievements_page.progress.text == "0 / 4 unlocked")
	assert(prep.achievements_page.rows.first_tower.text.begins_with("Locked"))
	assert(not toast.panel.visible)
	prep.go_back()
	assert(root.gui_get_focus_owner() == prep.achievements_button)
	scene.banked_energy = 1000
	var builder = scene.get_node("BuildController")
	builder.begin_placement()
	assert(builder.try_place(Vector2(120, 120)))
	assert(toast.panel.visible and toast.label.text.contains("Growing the Light"))
	assert(toast.panel.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	scene.achievements.unlock("first_tower")
	assert(toast.queue.is_empty(), "Repeated events cannot produce duplicate popups")
	toast.set_process(false)
	prep.open_view(prep.View.HOME)
	await settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		assert(toast.panel.size.y < 160, "Popup stays compact after layout")
		assert(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(toast.panel.get_global_rect()))
		root.get_texture().get_image().save_png("/tmp/lll-achievement-popup.png")
	toast.remaining = 0.0
	toast._next()
	assert(not toast.panel.visible)
	prep.open_view(prep.View.ACHIEVEMENTS)
	await settle()
	assert(prep.achievements_page.progress.text == "1 / 4 unlocked")
	assert(prep.achievements_page.rows.first_tower.text.begins_with("Unlocked"))
	assert(prep.achievements_page.retry_button.disabled)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/lll-achievements-menu.png")
	root.size = Vector2i(640, 480)
	await settle()
	assert(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(prep.back_button.get_global_rect()))
	assert(prep.back_button.is_visible_in_tree())
	assert(preload("res://game/online_config.gd").api_url() == str(ProjectSettings.get_setting("leaderboard/dev_api_url")), "Editor selects dev Convex")
	scene.free()
	await settle()
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".achievements-editor.json")
	print("PASS: achievement menu, locked/unlocked rows, first purchase popup, deduplication, expiry, return focus, compact layout and dev endpoint")
	quit()
