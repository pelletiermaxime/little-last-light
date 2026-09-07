extends SceneTree


func _initialize() -> void:
	call_deferred("check")


func check() -> void:
	# This scripted test races many complete runs; audio has its own regression.
	root.get_node("GameAudio").muted = true
	var scene = load("res://main.tscn").instantiate()
	var path := "/tmp/lll-final-test-%d.json" % OS.get_process_id()
	scene.save_path = path
	scene.game_version = "0.16.0"
	root.add_child(scene)
	scene.set_process(false)
	scene.lantern.set_process(false)
	scene.lantern.set_physics_process(false)
	scene.get_node("GameHUD").leaderboard.api_url = ""
	scene.start_run()
	scene._set_turrets_active(false)
	scene.lantern.elapsed = 300
	scene._process(0.01)
	var drencher = get_nodes_in_group("bosses")[0]
	drencher.trail.leave_puddle(scene.lantern.position)
	var existing_enemies := get_nodes_in_group("enemies")
	for enemy in existing_enemies:
		enemy.set_process(false)
	drencher.trail.set_process(false)
	scene.lantern.elapsed = 899.99
	assert(not scene.update_final_encounter())
	scene.lantern.elapsed = 900
	assert(scene.update_final_encounter())
	assert(not drencher.is_queued_for_deletion() and not get_nodes_in_group("hazards").is_empty(), "Final arrival preserves Drencher and water")
	for enemy in existing_enemies:
		assert(not enemy.is_queued_for_deletion() and enemy.is_in_group("enemies"), "Existing enemies remain in combat")
	var boss = get_nodes_in_group("final_bosses")[0]
	boss.set_process(false)
	assert(get_nodes_in_group("enemies").size() == existing_enemies.size() + 1)
	scene._process(0.5)
	assert(get_nodes_in_group("enemies").size() > existing_enemies.size() + 1, "Normal scheduling keeps spawning during final combat")
	var before_extra_spawns := get_nodes_in_group("enemies").size()
	scene._spawn_enemy()
	scene._spawn_charger()
	scene._spawn_boss()
	assert(get_nodes_in_group("final_bosses").size() == 1 and get_nodes_in_group("enemies").size() == before_extra_spawns + 2, "Pursuers and chargers can spawn; final boss remains unique")
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_process(false)
	boss.take_damage(9999)
	assert(boss.health == 1200, "Arrival cannot be skipped by a strong layout")
	var start: Vector2 = boss.position
	boss._process(3.0)
	assert(boss.position == start and boss.attack == boss.Attack.VOLLEY_WARNING)
	assert(boss.arrival_remaining == 0)
	# The one-minute launcher reaches the Snuffer before the Drencher ever spawns.
	scene.boss_spawned = false
	var hud = scene.get_node("GameHUD")
	hud.refresh()
	assert(hud.boss_status.visible)
	assert(hud.boss_text.text.begins_with("THE SNUFFER"), "Final boss HUD takes priority over a living Drencher")
	hud.refresh_elapsed = 0.0
	hud._process(0.01)
	assert(hud.boss_status.visible, "Snuffer status stays visible between HUD refreshes without a prior Drencher")
	if "--capture-final" in OS.get_cmdline_user_args():
		boss.position = Vector2(360, 360)
		scene.lantern.position = Vector2(480, 360)
		boss.heading = Vector2.RIGHT
		boss.queue_redraw()
		scene.get_node("GameHUD").refresh()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/lll-final-volley.png")
	scene.lantern.health = 100
	boss.take_damage(800)
	assert(boss.enraged)
	# Pause stops the normal scheduler and attack clocks.
	scene.get_node("PauseScreen").pause()
	boss.set_process(true)
	var remaining: float = boss.remaining
	await process_frame
	await process_frame
	assert(boss.remaining == remaining)
	scene.get_node("PauseScreen").resume()
	boss.set_process(false)
	# Existing turret targeting/damage works without special cases.
	boss.position = scene.get_arena_rect().get_center()
	var turret = scene.get_node("Turret")
	turret.position = boss.position + Vector2(50, 0)
	turret._process(0.01)
	assert(boss.health == 399)
	scene.lantern.elapsed = 942.125
	scene.lantern.energy = 123
	boss.take_damage(1000)
	assert(scene.phase == scene.Phase.RESULTS and scene.last_run.victory)
	assert(scene.banked_energy == 123 and scene.lantern.energy == 0)
	assert(scene.version_clears[scene.game_version] == 942.125)
	assert(scene.leaderboard_profile.pending.clearTimeMs == 942125)
	assert(scene.leaderboard_profile.pending.durationMs == 900000)
	assert(get_nodes_in_group("enemies").is_empty() and get_nodes_in_group("final_bosses").is_empty())
	assert(get_nodes_in_group("hazards").is_empty(), "Victory clears the retained Drencher water too")
	scene._on_final_boss_defeated()
	scene.lantern.take_damage(10000)
	scene.end_run()
	assert(scene.banked_energy == 123 and scene.last_run.victory, "Victory latches before later damage")
	var results = scene.get_node("ResultsScreen")
	assert(results.title.text == "Dawn has come" and results.stats.text.contains("15:42"))
	assert(scene._valid_save(JSON.parse_string(FileAccess.get_file_as_string(path))))
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(saved.version_clears[scene.game_version] == 942.125)
	if "--capture-final" in OS.get_cmdline_user_args():
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/lll-final-results.png")
	scene.continue_to_preparation()
	assert(not results.overlay.visible)
	scene.start_run()
	assert(not scene.final_boss_spawned)
	scene._set_turrets_active(false)
	scene.lantern.elapsed = 900
	scene.update_final_encounter()
	boss = get_nodes_in_group("final_bosses")[0]
	boss.set_process(false)
	boss._process(3.0)
	scene.lantern.energy = 7
	scene.lantern.take_damage(10000)
	boss.take_damage(10000)
	assert(not scene.last_run.victory and scene.banked_energy == 130, "Death first cannot be upgraded to victory")
	assert(scene.leaderboard_profile.pending.clearTimeMs == 942125, "A loss preserves the unpublished clear")
	scene.continue_to_preparation()
	scene.start_run()
	scene._set_turrets_active(false)
	scene.lantern.elapsed = 950
	scene.update_final_encounter()
	boss = get_nodes_in_group("final_bosses")[0]
	boss._process(3.0)
	boss.take_damage(10000)
	assert(scene.version_clears[scene.game_version] == 942.125 and not scene.last_run.new_best)
	scene.continue_to_preparation()
	scene.load_progress()
	assert(scene.version_clears[scene.game_version] == 942.125)
	# A faster clear replaces the pending record even though survival is tied.
	scene.start_run()
	scene._set_turrets_active(false)
	scene.lantern.elapsed = 920
	scene.update_final_encounter()
	boss = get_nodes_in_group("final_bosses")[0]
	boss._process(3)
	boss.take_damage(10000)
	assert(scene.last_run.new_best and scene.leaderboard_profile.pending.clearTimeMs == 920000)
	scene.continue_to_preparation()
	scene.start_run()
	scene._set_turrets_active(false)
	scene.lantern.elapsed = 900
	scene.update_final_encounter()
	scene.get_node("PauseScreen").pause()
	scene.get_node("PauseScreen").end_run()
	assert(not paused and get_nodes_in_group("final_bosses").is_empty() and not scene.last_run.victory)
	var legacy := saved.duplicate(true)
	legacy.erase("version_clears")
	legacy.leaderboard.pending.erase("clearTimeMs")
	legacy.version_bests[scene.game_version] = 1500.0
	assert(scene._valid_save(legacy), "Existing long survival records remain valid")
	var invalid := saved.duplicate(true)
	invalid.version_clears[scene.game_version] = -1
	assert(not scene._valid_save(invalid))
	scene.free()
	await process_frame
	DirAccess.remove_absolute(path)
	print("PASS: M16 spawn once, retained enemies and Drencher water, final HUD priority, pause, damage, victory cleanup, single banking, death ordering and records")
	quit()
