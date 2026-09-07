extends SceneTree


func _initialize() -> void:
	root.get_node("DisplaySettings").settings_path = "/tmp/lll-watchlight-display.cfg"
	root.get_node("DisplaySettings").windowed_size = Vector2i(1152, 760)
	root.get_node("DisplaySettings").display_mode = "Windowed"
	root.get_node("DisplaySettings").windowed_maximized = false
	call_deferred("launch")


func launch() -> void:
	# Screenshot mode exits before sound effects finish; keep it silent.
	if "--capture-watchlight" in OS.get_cmdline_user_args():
		root.get_node("GameAudio").muted = true
	ProjectSettings.set_setting("leaderboard/api_url", "")
	var scene = load("res://main.tscn").instantiate()
	scene.save_path = "/tmp/lll-watchlight-playtest-%d.json" % OS.get_process_id()
	root.add_child(scene)
	current_scene = scene
	root.title = "Little Last Light — Watchlight playtest"
	scene.banked_energy = 1200
	var build = scene.get_node("BuildController")
	var center: Vector2 = scene.get_arena_rect().get_center()
	for offset in [Vector2(-140, -70), Vector2(120, -150)]:
		build.begin_placement("sniper")
		build.try_place(center + offset)
	build.begin_placement("pulse")
	build.try_place(center + Vector2(-10, 125))
	scene.get_node("PreparationUI").open_view(0)
	print("READY: two Watchlights, a basic turret and a slow turret; 765 energy; temporary save; leaderboards disabled")
	if "--capture-watchlight" in OS.get_cmdline_user_args():
		await process_frame
		await process_frame
		scene.get_node("PreparationUI").open_view(1)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/lll-watchlight-placement.png")
		scene.start_run()
		scene.set_process(false)
		scene.lantern.set_process(false)
		scene.lantern.set_physics_process(false)
		scene.lantern.position = center
		scene._set_turrets_active(false)
		for offset in [Vector2(250, -200), Vector2(-310, -140), Vector2(230, 150)]:
			scene._spawn_enemy()
			var enemy = get_nodes_in_group("enemies").back()
			enemy.position = center + offset
			enemy.health = 10
			enemy.max_health = 10
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
		for turret in get_nodes_in_group("turrets"):
			turret._process(0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/lll-watchlight-combat.png")
		print("Captured Watchlight placement and combat")
		# Leave the render callback before releasing the full game scene.
		await process_frame
		scene.queue_free()
		await process_frame
		quit()
