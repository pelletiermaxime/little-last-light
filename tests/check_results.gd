extends SceneTree


func _initialize() -> void:
	call_deferred("check")


func check() -> void:
	var scene = load("res://main.tscn").instantiate()
	var path := "/tmp/lll-results-test-%d.json" % OS.get_process_id()
	scene.save_path = path
	scene.game_version = "0.1.0"
	root.add_child(scene)
	scene.set_process(false)
	scene.lantern.set_process(false)
	var hud = scene.get_node("GameHUD")
	var panel = hud.leaderboard
	panel.api_url = ""
	var results = scene.get_node("ResultsScreen")
	scene.start_run()
	scene.lantern.elapsed = 123.0
	scene.lantern.energy = 77.0
	scene.lantern.take_damage(1000)
	assert(scene.phase == scene.Phase.RESULTS and results.overlay.visible)
	assert(results.stats.text.contains("02:03") and results.stats.text.contains("77"))
	assert(panel.get_parent() == results.content and panel.publish.visible)
	assert(not hud.scroll.visible and scene.banked_energy == 77.0)
	scene.end_run()
	scene.start_run()
	assert(scene.phase == scene.Phase.RESULTS and scene.banked_energy == 77.0)
	assert(not scene.buy_upgrade("damage"))
	var build = scene.get_node("BuildController")
	build.begin_placement()
	assert(not build.placing)
	results.continue_button.pressed.emit()
	assert(scene.phase == scene.Phase.PREPARATION and not results.overlay.visible)
	assert(panel == hud.leaderboard and panel.get_parent() == scene.get_node("PreparationUI").records_host)
	assert(not hud.scroll.visible and panel.publish.visible)
	scene.get_node("PreparationUI").open_view(3)
	assert(panel.is_visible_in_tree(), "Pending record remains reachable from preparation")
	scene.start_run()
	scene.lantern.elapsed = 150.0
	scene.lantern.energy = 9.0
	scene.get_node("PauseScreen").pause()
	scene.get_node("PauseScreen").end_run()
	assert(not paused and results.overlay.visible and results.title.text == "Run ended")
	assert(scene.banked_energy == 86.0 and panel.get_parent() == results.content)
	if "--capture-results" in OS.get_cmdline_user_args():
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/lll-results-preview.png")
	scene.free()
	DirAccess.remove_absolute(path)
	print("PASS: results recap, single banking, locked purchases, persistent leaderboard panel, Continue, paused End Run")
	quit()
